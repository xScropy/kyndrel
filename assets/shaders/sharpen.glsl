// Kyndrel light sharpen (GPL-3.0, part of Kyndrel).
// A gentle unsharp mask on luma: adds back half the difference between a
// pixel and the average of its four neighbours.
//!HOOK LUMA
//!BIND HOOKED
//!DESC Kyndrel light sharpen
vec4 hook() {
    vec4 c = HOOKED_tex(HOOKED_pos);
    vec4 blur = (HOOKED_texOff(vec2(1.0, 0.0)) + HOOKED_texOff(vec2(-1.0, 0.0)) +
                 HOOKED_texOff(vec2(0.0, 1.0)) + HOOKED_texOff(vec2(0.0, -1.0))) * 0.25;
    return clamp(c + (c - blur) * 0.5, 0.0, 1.0);
}
