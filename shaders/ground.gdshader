shader_type spatial;

// Ground shader — zone fill + grid, driven by SDF union of claims.
//
// Each claim contributes `sdf_i = d - r` (signed distance to its
// boundary: negative inside, positive outside). Per team we take a
// SMOOTH-MIN over the claims to get the union SDF with rounded
// concave corners where two arcs meet (controlled by
// `corner_round_radius`, in world units).
//
// Zone color is determined by which team SDF is more negative.

const int MAX_CLAIMS = 64;

uniform int   claim_count = 0;
uniform vec2  claim_positions[MAX_CLAIMS];
uniform float claim_radii[MAX_CLAIMS];
uniform float claim_min_radii[MAX_CLAIMS];
uniform float claim_signs[MAX_CLAIMS];

uniform vec4  color_blue    : source_color = vec4(0.82, 0.87, 0.97, 1.0);
uniform vec4  color_red     : source_color = vec4(0.97, 0.83, 0.83, 1.0);
uniform vec4  color_neutral : source_color = vec4(0.90, 0.90, 0.92, 1.0);
uniform vec4  color_grid    : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// AA band width at the zone boundary, in screen pixels.
uniform float zone_edge_aa_px = 1.5;

// Corner rounding for the smooth-min union (world units). Where two
// same-team claims' boundary arcs meet, the concave corner is
// rounded with this radius. 0 = sharp union (plain min).
uniform float corner_round_radius = 0.8;

// Extra SDF depth (world units) applied inside a claim's min bubble
// via a smooth quadratic taper. Makes the bubble "deeply owned" so
// opposing teams can never push the ownership inside it.
uniform float min_bubble_extra_depth = 10.0;

uniform float grid_spacing = 2.0;
uniform float grid_pixel_width = 1.8;
uniform float grid_opacity = 0.30;

varying vec2 world_xz;


// Inigo Quilez polynomial smooth-min. When |a - b| >= k the result
// is exactly min(a, b). Inside a band of width k around the ridge,
// the result dips slightly below min, giving a rounded blend.
float smin(float a, float b, float k) {
	if (k <= 1e-6) {
		return min(a, b);
	}
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * h * k * (1.0 / 6.0);
}


// Per-claim SDF with the min-bubble depth boost baked in.
float claim_sdf(vec2 point, int i) {
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


void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_xz = wp.xz;
}


void fragment() {
	vec2 p = world_xz;

	vec2 fw_p = fwidth(p);
	float px_in_world = max(fw_p.x, fw_p.y);
	float edge_aa_world = zone_edge_aa_px * px_in_world;

	// Per-team union SDF via smooth-min over claims.
	float player_sdf = 1e6;
	float enemy_sdf = 1e6;

	for (int i = 0; i < claim_count; i++) {
		float r = claim_radii[i];
		if (r <= 0.0) {
			continue;
		}
		float sdf_i = claim_sdf(p, i);
		if (claim_signs[i] > 0.0) {
			player_sdf = smin(player_sdf, sdf_i, corner_round_radius);
		} else {
			enemy_sdf = smin(enemy_sdf, sdf_i, corner_round_radius);
		}
	}

	// Zone SDF = signed distance to the nearest zone boundary
	// (negative inside any zone, positive in neutral).
	float zone_sdf = min(player_sdf, enemy_sdf);

	// Inside factor: fade from 1 inside the union to 0 outside.
	float inside_any = 1.0 - smoothstep(-edge_aa_world, edge_aa_world, zone_sdf);

	// Which team owns this pixel? The one with the more-negative
	// (deeper inside) SDF. In pure-neutral areas both are positive
	// and the choice doesn't matter because inside_any is 0.
	vec3 zone_color = (player_sdf <= enemy_sdf) ? color_blue.rgb : color_red.rgb;
	vec3 base = mix(color_neutral.rgb, zone_color, inside_any);

	// Subtle grid pattern.
	if (grid_opacity > 0.0 && grid_spacing > 0.0) {
		vec2 grid_coord = world_xz / grid_spacing;
		vec2 grid_fract = abs(fract(grid_coord) - 0.5);
		float grid_dist = min(grid_fract.x, grid_fract.y);
		vec2 fw_grid = fwidth(grid_coord);
		float fw_avg = (fw_grid.x + fw_grid.y) * 0.5;
		if (fw_avg > 1e-7) {
			float grid_half = 0.5 * grid_pixel_width * fw_avg;
			float grid_line = 1.0 - smoothstep(0.0, grid_half, grid_dist);
			base = mix(base, color_grid.rgb, grid_line * grid_opacity);
		}
	}

	ALBEDO = base;
}
