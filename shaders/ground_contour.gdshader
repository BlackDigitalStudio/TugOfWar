shader_type spatial;
render_mode alpha_to_coverage, unshaded, cull_disabled, depth_draw_never;

// Contour overlay shader — draws the complete territory boundary
// composed of three candidate arms:
//
//   1. Player outer:  player_sdf = 0, valid where enemy_sdf >= 0
//   2. Enemy  outer:  enemy_sdf  = 0, valid where player_sdf >= 0
//   3. Front line:    player_sdf = enemy_sdf, valid inside contested
//                     (both sdfs <= 0)
//
// For each SSAA sample, we compute the PIXEL-SPACE distance from
// the sample to each arm's isoline:
//
//     d_arm = |scalar| / |hardware gradient of scalar|
//
// This gives CONSTANT line thickness regardless of local geometry.
//
// Invalid components are excluded by adding a large penalty
// proportional to how far the sample has strayed into the forbidden
// region (measured in pixels). The penalty is continuous in sdf
// space, so SSAA produces smooth transitions at the mask edges.
//
// The three distances are combined via smooth-min (`smin`) so the
// three-way junction where the arms meet is ROUNDED with a radius
// derived from corner_round_radius — matching the same-team union
// rounding applied inside compute_team_sdfs.
//
// AA stack: engine 2× SSAA + 8× shader SSAA + MSAA 8× alpha-to-
// coverage stippling.

const int MAX_CLAIMS = 64;

uniform int   claim_count = 0;
uniform vec2  claim_positions[MAX_CLAIMS];
uniform float claim_radii[MAX_CLAIMS];
uniform float claim_min_radii[MAX_CLAIMS];
uniform float claim_signs[MAX_CLAIMS];

uniform vec4  color_band : source_color = vec4(0.05, 0.05, 0.07, 1.0);

uniform float line_core_half_px = 4.0;
uniform float line_aa_px = 10.0;

uniform float corner_round_radius = 0.8;
uniform float min_bubble_extra_depth = 10.0;

varying vec2 world_xz;


float smin(float a, float b, float k) {
	if (k <= 1e-6) {
		return min(a, b);
	}
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * h * k * (1.0 / 6.0);
}


float claim_sdf_at(vec2 point, int i) {
	float r = claim_radii[i];
	float min_r = claim_min_radii[i];
	float d = distance(claim_positions[i], point);

	float sdf = d - r;

	if (min_r > 0.0 && d < min_r) {
		float u = d / min_r;
		float v = 1.0 - u * u;
		sdf -= min_bubble_extra_depth * v * v;
	}

	return sdf;
}


void compute_team_sdfs(vec2 point, out float player_sdf, out float enemy_sdf) {
	player_sdf = 1e6;
	enemy_sdf = 1e6;

	for (int i = 0; i < claim_count; i++) {
		float r = claim_radii[i];
		if (r <= 0.0) {
			continue;
		}
		float sdf_i = claim_sdf_at(point, i);
		if (claim_signs[i] > 0.0) {
			player_sdf = smin(player_sdf, sdf_i, corner_round_radius);
		} else {
			enemy_sdf = smin(enemy_sdf, sdf_i, corner_round_radius);
		}
	}
}


void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_xz = wp.xz;
}


void fragment() {
	vec2 p = world_xz;
	vec2 dp_dx = dFdx(p);
	vec2 dp_dy = dFdy(p);

	// Pixel-center per-team SDFs. Per-team SDFs are smooth (smin
	// over same-team claims), so hardware dFdx/dFdy give accurate
	// gradients that are stable across the pixel quad.
	float p_c;
	float e_c;
	compute_team_sdfs(p, p_c, e_c);

	// Gradients in sdf-units per screen-pixel.
	vec2 p_grad_px = vec2(dFdx(p_c), dFdy(p_c));
	vec2 e_grad_px = vec2(dFdx(e_c), dFdy(e_c));
	vec2 front_grad_px = (p_grad_px - e_grad_px) * 0.5;

	float p_glen = length(p_grad_px);
	float e_glen = length(e_grad_px);
	float front_glen = length(front_grad_px);

	// Rounding radius for the three-way junction in pixel units.
	// Uses the world-to-pixel scale directly (not an sdf gradient)
	// so the rounding is consistent regardless of local sdf shape.
	float world_per_px = 0.5 * (length(dp_dx) + length(dp_dy));
	float round_px = corner_round_radius / max(world_per_px, 1e-7);
	round_px = clamp(round_px, 2.0, 24.0);

	vec2 ssaa_offsets[8] = vec2[8](
		vec2( 0.0625, -0.1875),
		vec2(-0.1875,  0.0625),
		vec2( 0.1875,  0.3125),
		vec2(-0.3125, -0.1875),
		vec2( 0.3125, -0.3125),
		vec2(-0.0625,  0.4375),
		vec2( 0.4375,  0.0625),
		vec2(-0.4375, -0.4375)
	);

	// Penalty multiplier for invalid components: how many extra
	// pixels of distance per one pixel of sdf violation. A value
	// of 200 makes a 0.1-pixel violation push distance past the
	// line_core + line_aa band (14 px total), so invalid samples
	// are excluded almost immediately.
	const float PENALTY_MUL = 200.0;
	const float INF = 1e5;

	float line_sum = 0.0;
	for (int s = 0; s < 8; s++) {
		vec2 p_sample = p + ssaa_offsets[s].x * dp_dx
		                + ssaa_offsets[s].y * dp_dy;
		float p_s;
		float e_s;
		compute_team_sdfs(p_sample, p_s, e_s);

		// --- Candidate arm distances in pixel units --------------
		float d_po = INF;
		float d_eo = INF;
		float d_f  = INF;

		if (p_glen > 1e-7) {
			d_po = abs(p_s) / p_glen;
			// Player outer invalid where enemy is present (e < 0).
			d_po += max(0.0, -e_s) / max(e_glen, 1e-7) * PENALTY_MUL;
		}

		if (e_glen > 1e-7) {
			d_eo = abs(e_s) / e_glen;
			// Enemy outer invalid where player is present (p < 0).
			d_eo += max(0.0, -p_s) / max(p_glen, 1e-7) * PENALTY_MUL;
		}

		if (front_glen > 1e-7) {
			d_f = abs(p_s - e_s) * 0.5 / front_glen;
			// Front invalid outside contested (max(p, e) > 0).
			float outside = max(0.0, max(p_s, e_s));
			float outside_glen = max(p_glen, e_glen);
			d_f += outside / max(outside_glen, 1e-7) * PENALTY_MUL;
		}

		// --- Rounded combination of the three arms ---------------
		// smin of distances smoothly joins the arms at the junction
		// with a radius of `round_px` pixels. Where only one arm is
		// close, smin degrades to plain min (unchanged thickness).
		float d_outer = smin(d_po, d_eo, round_px);
		float d_all = smin(d_outer, d_f, round_px);

		float line_s = 1.0 - smoothstep(
			line_core_half_px,
			line_core_half_px + line_aa_px,
			d_all
		);
		line_sum += line_s;
	}
	float line = line_sum * 0.125;

	ALBEDO = color_band.rgb;
	ALPHA = line;
}
