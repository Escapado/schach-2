// Shared by the sky and its mirrored water reflection.
// Speed is measured in 640-wide art pixels per second, not quantized steps.
const float CLOUD_DRIFT_SPEED = 8.4;

vec2 drifting_cloud_uv(vec2 uv, float elapsed) {
	uv.x = fract(uv.x + elapsed * CLOUD_DRIFT_SPEED / 640.0);
	return uv;
}
