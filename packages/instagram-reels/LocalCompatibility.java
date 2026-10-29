package local.instagram;

import app.morphe.patcher.patch.Compatibility;

public final class LocalCompatibility {
    public static Compatibility create(String version) {
        return Compatibility.Companion.fromLegacy(
            new kotlin.Pair<>("com.instagram.android", java.util.Set.of(version))
        );
    }
}
