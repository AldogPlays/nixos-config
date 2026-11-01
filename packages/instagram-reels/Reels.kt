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
import com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction
import com.android.tools.smali.dexlib2.iface.reference.MethodReference
import com.android.tools.smali.dexlib2.iface.reference.StringReference
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
private object Startup : Fingerprint(
    strings = listOf("MainActivityAccountHelper.STARTUP_TAB"),
    parameters = listOf("Landroid/content/Intent;", "Lcom/instagram/common/session/UserSession;", "Z"),
    returnType = "V",
)
private object TabRouter : Fingerprint(strings = listOf("feed_viewpager_empty_tabs"), returnType = "V")
private object TabHistory : Fingerprint(strings = listOf("NavigationController.pushTabFragment"), returnType = "V")
private object ReelRefresh : Fingerprint(
    name = "onInterceptTouchEvent",
    parameters = listOf("Landroid/view/MotionEvent;"),
    definingClass = "Linstagram/features/clips/viewer/ui/ClipsSwipeRefreshLayout;",
)
private object BlendHeader : Fingerprint(
    strings = listOf("show_blends_add_icon_for_thread"),
    custom = { method, _ ->
        method.parameterTypes.take(3).map(CharSequence::toString) == listOf(
            "Landroid/content/Context;", "Lcom/instagram/common/session/UserSession;",
            "Lcom/instagram/direct/capabilities/Capabilities;"
        )
    },
)
private object BlendUtil : Fingerprint(strings = listOf("android_purge_26_q2_BlendUtil_shouldBadge"))
private const val SUPPORTED_VERSION = "@INSTAGRAM_VERSION@"
private const val SUPPORTED_CODE = "@INSTAGRAM_VERSION_CODE@"
private fun compatibility() = LocalCompatibility.create(SUPPORTED_VERSION)

val hideFeeds = bytecodePatch(name = "Local hide Home and Reels navigation", default = false) {
    compatibleWith(compatibility())
    execute {
        require(packageMetadata.versionName == SUPPORTED_VERSION && packageMetadata.versionCode == SUPPORTED_CODE)
        val match = Navigation.matchAll(0..Int.MAX_VALUE).single()
        val method = match.method
        val owner = match.classDef
        println("Verified navigation initializer: $method")
        require(owner.methods.none { it.name == "nixosWithoutFeeds" })
        val helper = MutableMethod(ImmutableMethod(
            owner.type, "nixosWithoutFeeds",
            listOf(ImmutableMethodParameter("Ljava/util/List;", emptySet(), null)),
            "Ljava/util/List;", AccessFlags.PUBLIC.value or AccessFlags.STATIC.value,
            emptySet(), emptySet(), ImmutableMethodImplementation(9, emptyList(), emptyList(), emptyList())
        ))
        // Copy the list before filtering, including when Instagram returns an immutable list.
        // Match the semantic fragment ID rather than an obfuscated class/field name.
        helper.addInstructions(0, """
            const/4 v7, 0x0
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
            move-result p0
            if-nez p0, :remove
            const-string p0, "fragment_feed"
            invoke-virtual {p0, v6}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
            move-result p0
            if-nez p0, :remove
            const-string p0, "fragment_direct_tab"
            invoke-virtual {p0, v6}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
            move-result p0
            if-eqz p0, :skip
            move-object v7, v2
            goto :skip
            :remove
            invoke-interface {v1}, Ljava/util/Iterator;->remove()V
            goto :next
            :skip
            add-int/lit8 v4, v4, 0x1
            goto :field
            :done
            if-eqz v7, :return
            invoke-interface {v0, v7}, Ljava/util/List;->remove(Ljava/lang/Object;)Z
            const/4 v6, 0x0
            invoke-interface {v0, v6, v7}, Ljava/util/List;->add(ILjava/lang/Object;)V
            :return
            return-object v0
        """)
        owner.methods.add(helper)
        val returns = method.instructions.withIndex().filter { it.value.opcode == Opcode.RETURN_OBJECT }
        require(returns.isNotEmpty())
        for ((index, instruction) in returns.reversed()) {
            val register = (instruction as OneRegisterInstruction).registerA
            require(register < 16)
            method.replaceInstruction(index, "invoke-static {v$register}, ${owner.type}->nixosWithoutFeeds(Ljava/util/List;)Ljava/util/List;")
            method.addInstructions(index + 1, "move-result-object v$register\nreturn-object v$register")
        }
        // Instagram can select FEED independently of the visible navigation list.
        // Use its native startup extra, preserving explicit non-feed destinations.
        val startup = Startup.matchAll(0..Int.MAX_VALUE).single().method
        require(!AccessFlags.STATIC.isSet(startup.accessFlags))
        val registers = requireNotNull(startup.implementation).registerCount
        require(registers - 4 >= 2 && registers < 16)
        println("Verified navigation startup: $startup")
        startup.addInstructions(0, """
            if-eqz p1, :native_start
            const-string v0, "MainActivityAccountHelper.STARTUP_TAB"
            invoke-virtual {p1, v0}, Landroid/content/Intent;->getStringExtra(Ljava/lang/String;)Ljava/lang/String;
            move-result-object v1
            if-eqz v1, :direct_start
            const-string v0, "FEED"
            invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
            move-result v0
            if-nez v0, :direct_start
            const-string v0, "CLIPS"
            invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
            move-result v0
            if-eqz v0, :native_start
            :direct_start
            const-string v0, "MainActivityAccountHelper.STARTUP_TAB"
            const-string v1, "DIRECT"
            invoke-virtual {p1, v0, v1}, Landroid/content/Intent;->putExtra(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;
            const/4 p3, 0x1
            :native_start
            nop
        """)
        // The native Back path also requests FEED. Redirect tab selection itself
        // so it cannot reopen a hidden feed after the startup hook has finished.
        val router = TabRouter.matchAll(0..Int.MAX_VALUE).single().method
        val tabType = router.parameterTypes.first().toString()
        require(!AccessFlags.STATIC.isSet(router.accessFlags))
        require(router.parameterTypes.map(CharSequence::toString) == listOf(tabType, "Ljava/lang/String;", "Z"))
        require(requireNotNull(router.implementation).registerCount - 4 >= 2)
        println("Verified tab-selection router: $router")
        val history = TabHistory.matchAll(0..Int.MAX_VALUE).single().method
        require(!AccessFlags.STATIC.isSet(history.accessFlags))
        require(history.parameterTypes.map(CharSequence::toString) == listOf(tabType, tabType, "Z", "Z"))
        require(requireNotNull(history.implementation).registerCount - 5 >= 2)
        println("Verified tab-history router: $history")
        for ((target, parameter) in listOf(router to "p1", history to "p2")) {
          target.addInstructions(0, """
            move-object/from16 v0, $parameter
            if-eqz v0, :native_tab
            invoke-virtual {v0}, Ljava/lang/Enum;->name()Ljava/lang/String;
            move-result-object v0
            const-string v1, "FEED"
            invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
            move-result v1
            if-nez v1, :direct_tab
            const-string v1, "CLIPS"
            invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
            move-result v1
            if-eqz v1, :native_tab
            :direct_tab
            const-string v0, "DIRECT"
            invoke-static {v0}, $tabType->valueOf(Ljava/lang/String;)$tabType
            move-result-object v0
            move-object/16 $parameter, v0
            :native_tab
            nop
        """)
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

val hideBlend = bytecodePatch(name = "Local hide messaging Blend button", default = false) {
    compatibleWith(compatibility())
    execute {
        require(packageMetadata.versionName == SUPPORTED_VERSION && packageMetadata.versionCode == SUPPORTED_CODE)
        val header = BlendHeader.matchAll(0..Int.MAX_VALUE).single()
        val method = header.method
        val utility = BlendUtil.matchAll(0..Int.MAX_VALUE).single().classDef.type
        val session = "Lcom/instagram/common/session/UserSession;"
        val instructions = method.instructions.toList()
        fun reference(index: Int) = (instructions[index] as? ReferenceInstruction)?.reference

        // Resolve native Blend gates from the semantic anchors and call graph,
        // rather than persisting this release's obfuscated class/method names.
        val enabled = instructions.indices.mapNotNull { reference(it) as? MethodReference }
            .filter { it.definingClass == utility && it.returnType == "Z" &&
                it.parameterTypes.map(CharSequence::toString) == listOf(session) }
            .distinct().single()
        val canStart = header.classDef.methods.single { candidate ->
            candidate.returnType == "Z" && candidate.parameterTypes.size == 2 &&
                candidate.parameterTypes.first().toString() == session &&
                candidate.instructions.any { (it as? ReferenceInstruction)?.reference == enabled }
        }
        val gates = instructions.indices.filter { reference(it) == enabled || reference(it) == canStart }
        require(gates.size == 3) { "Expected one Blend entrypoint and two creation checks in the messaging header" }

        val preference = instructions.indices.single {
            (reference(it) as? StringReference)?.string == "show_blends_add_icon_for_thread"
        }
        val addIcon = (preference + 1 until minOf(preference + 14, instructions.size)).first { index ->
            val ref = reference(index) as? MethodReference
            ref?.name == "getBoolean" && ref.returnType == "Z" &&
                ref.parameterTypes.map(CharSequence::toString) == listOf("Ljava/lang/String;", "Z")
        }
        for (index in gates + addIcon) {
            val result = instructions[index + 1]
            require(result.opcode == Opcode.MOVE_RESULT)
            val register = (result as OneRegisterInstruction).registerA
            method.replaceInstruction(index + 1, "const/16 v$register, 0x0")
        }
        println("Verified messaging Blend header: $method; disabled four local UI decisions")
    }
}
