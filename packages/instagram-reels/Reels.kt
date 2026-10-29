// SPDX-License-Identifier: GPL-3.0-only
// Fingerprints and the scrolling hook are adapted from ReVanced's Instagram patches.
package local.instagram

import app.morphe.patcher.Fingerprint
import app.morphe.patcher.OpcodesFilter
import app.morphe.patcher.extensions.InstructionExtensions.addInstructions
import app.morphe.patcher.extensions.InstructionExtensions.instructions
import app.morphe.patcher.extensions.InstructionExtensions.replaceInstruction
import app.morphe.patcher.patch.bytecodePatch
import app.morphe.patcher.util.proxy.mutableTypes.MutableMethod
import com.android.tools.smali.dexlib2.AccessFlags
import com.android.tools.smali.dexlib2.Opcode
import com.android.tools.smali.dexlib2.iface.instruction.OneRegisterInstruction
import com.android.tools.smali.dexlib2.immutable.ImmutableMethod
import com.android.tools.smali.dexlib2.immutable.ImmutableMethodImplementation
import com.android.tools.smali.dexlib2.immutable.ImmutableMethodParameter

private object Navigation : Fingerprint(
    accessFlags = listOf(AccessFlags.PUBLIC, AccessFlags.FINAL),
    parameters = listOf("Lcom/instagram/common/session/UserSession;", "Z"),
    returnType = "Ljava/util/List;",
    filters = OpcodesFilter.opcodesToFilters(
        Opcode.IF_EQZ, Opcode.INVOKE_STATIC, Opcode.MOVE_RESULT_OBJECT, Opcode.RETURN_OBJECT
    ),
)
private object ReelPager : Fingerprint(strings = listOf("ClipsViewPagerImpl_getViewAtIndex"))
private object ReelRefresh : Fingerprint(
    name = "onInterceptTouchEvent",
    parameters = listOf("Landroid/view/MotionEvent;"),
    definingClass = "Linstagram/features/clips/viewer/ui/ClipsSwipeRefreshLayout;",
)
private const val SUPPORTED_VERSION = "@INSTAGRAM_VERSION@"
private const val SUPPORTED_CODE = "@INSTAGRAM_VERSION_CODE@"
private fun compatibility() = LocalCompatibility.create(SUPPORTED_VERSION)

val hideReels = bytecodePatch(name = "Local hide Reels navigation", default = false) {
    compatibleWith(compatibility())
    execute {
        require(packageMetadata.versionName == SUPPORTED_VERSION && packageMetadata.versionCode == SUPPORTED_CODE)
        val match = Navigation.matchAll(0..Int.MAX_VALUE).single()
        val method = match.method
        val owner = match.classDef
        println("Verified navigation initializer: $method")
        require(owner.methods.none { it.name == "nixosWithoutReels" })
        val helper = MutableMethod(ImmutableMethod(
            owner.type, "nixosWithoutReels",
            listOf(ImmutableMethodParameter("Ljava/util/List;", emptySet(), null)),
            "Ljava/util/List;", AccessFlags.PUBLIC.value or AccessFlags.STATIC.value,
            emptySet(), emptySet(), ImmutableMethodImplementation(8, emptyList(), emptyList(), emptyList())
        ))
        // Copy the list before filtering, including when Instagram returns an immutable list.
        // Match the semantic fragment ID rather than an obfuscated class/field name.
        helper.addInstructions(0, """
            new-instance v0, Ljava/util/ArrayList;
            invoke-direct {v0, p0}, Ljava/util/ArrayList;-><init>(Ljava/util/Collection;)V
            invoke-interface {v0}, Ljava/util/List;->iterator()Ljava/util/Iterator;
            move-result-object v1
            :next
            invoke-interface {v1}, Ljava/util/Iterator;->hasNext()Z
            move-result v2
            if-eqz v2, :done
            invoke-interface {v1}, Ljava/util/Iterator;->next()Ljava/lang/Object;
            move-result-object v2
            invoke-virtual {v2}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
            move-result-object v3
            invoke-virtual {v3}, Ljava/lang/Class;->getDeclaredFields()[Ljava/lang/reflect/Field;
            move-result-object v3
            const/4 v4, 0x0
            :field
            array-length v5, v3
            if-ge v4, v5, :next
            aget-object v5, v3, v4
            invoke-virtual {v5}, Ljava/lang/reflect/Field;->getModifiers()I
            move-result v6
            and-int/lit8 v6, v6, 0x8
            if-nez v6, :skip
            invoke-virtual {v5}, Ljava/lang/reflect/Field;->getType()Ljava/lang/Class;
            move-result-object v6
            const-class p0, Ljava/lang/String;
            if-ne v6, p0, :skip
            const/4 v6, 0x1
            invoke-virtual {v5, v6}, Ljava/lang/reflect/Field;->setAccessible(Z)V
            invoke-virtual {v5, v2}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
            move-result-object v6
            const-string p0, "fragment_clips"
            invoke-virtual {p0, v6}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
            move-result v6
            if-eqz v6, :skip
            invoke-interface {v1}, Ljava/util/Iterator;->remove()V
            goto :next
            :skip
            add-int/lit8 v4, v4, 0x1
            goto :field
            :done
            return-object v0
        """)
        owner.methods.add(helper)
        val returns = method.instructions.withIndex().filter { it.value.opcode == Opcode.RETURN_OBJECT }
        require(returns.isNotEmpty())
        for ((index, instruction) in returns.reversed()) {
            val register = (instruction as OneRegisterInstruction).registerA
            require(register < 16)
            method.replaceInstruction(index, "invoke-static {v$register}, ${owner.type}->nixosWithoutReels(Ljava/util/List;)Ljava/util/List;")
            method.addInstructions(index + 1, "move-result-object v$register\nreturn-object v$register")
        }
    }
}

val stopReels = bytecodePatch(name = "Local stop Reels scrolling", default = false) {
    compatibleWith(compatibility())
    execute {
        require(packageMetadata.versionName == SUPPORTED_VERSION && packageMetadata.versionCode == SUPPORTED_CODE)
        val pager = ReelPager.matchAll(0..Int.MAX_VALUE).single()
        val field = pager.classDef.fields.single { it.type == "Landroidx/viewpager2/widget/ViewPager2;" }
        println("Verified Reels pager: ${pager.method}; field $field")
        pager.method.addInstructions(0, """
            iget-object v0, p0, $field
            const/4 v1, 0x0
            invoke-virtual {v0, v1}, Landroidx/viewpager2/widget/ViewPager2;->setUserInputEnabled(Z)V
        """)
        val refresh = ReelRefresh.matchAll(0..Int.MAX_VALUE).single().method
        require(refresh.returnType == "Z")
        refresh.addInstructions(0, "const/4 v0, 0x0\nreturn v0")
    }
}
