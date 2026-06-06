package app.provii.wallet.security

import app.provii.wallet.security.antiDebug.AntiDebugChecker
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for AntiDebugChecker
 *
 * Note: These tests validate the logic and data structures.
 * Full integration testing requires an Android device/emulator.
 */
class AntiDebugCheckerTest {
    @Test
    fun `AntiDebugResult isCompromised returns true when debugger attached`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = true,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Debugger attached"),
            )

        assertTrue("Should be compromised when debugger is attached", result.isCompromised)
    }

    @Test
    fun `AntiDebugResult isCompromised returns true when Frida detected`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = true,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Frida detected"),
            )

        assertTrue("Should be compromised when Frida is detected", result.isCompromised)
    }

    @Test
    fun `AntiDebugResult isCompromised returns true when Xposed detected`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = true,
                hasTracerPid = false,
                detectedThreats = listOf("Xposed detected"),
            )

        assertTrue("Should be compromised when Xposed is detected", result.isCompromised)
    }

    @Test
    fun `AntiDebugResult isCompromised returns true when process is traced`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = true,
                detectedThreats = listOf("Process traced"),
            )

        assertTrue("Should be compromised when process is traced", result.isCompromised)
    }

    @Test
    fun `AntiDebugResult isCompromised returns false when no threats`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
            )

        assertFalse("Should not be compromised when no threats", result.isCompromised)
    }

    @Test
    fun `AntiDebugResult isCompromised returns false when only debuggable`() {
        // Debuggable alone is not considered compromised (common in dev builds)
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = true,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Application is debuggable"),
            )

        assertFalse("Should not be compromised when only debuggable", result.isCompromised)
    }

    @Test
    fun `ThreatLevel is CRITICAL when Frida detected`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = true,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Frida detected"),
            )

        assertEquals(
            "Frida should result in CRITICAL threat level",
            AntiDebugChecker.ThreatLevel.CRITICAL,
            result.threatLevel,
        )
    }

    @Test
    fun `ThreatLevel is CRITICAL when Xposed detected`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = true,
                hasTracerPid = false,
                detectedThreats = listOf("Xposed detected"),
            )

        assertEquals(
            "Xposed should result in CRITICAL threat level",
            AntiDebugChecker.ThreatLevel.CRITICAL,
            result.threatLevel,
        )
    }

    @Test
    fun `ThreatLevel is HIGH when debugger attached`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = true,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Debugger attached"),
            )

        assertEquals(
            "Debugger attached should result in HIGH threat level",
            AntiDebugChecker.ThreatLevel.HIGH,
            result.threatLevel,
        )
    }

    @Test
    fun `ThreatLevel is MEDIUM when only debuggable`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = true,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = listOf("Application is debuggable"),
            )

        assertEquals(
            "Debuggable only should result in MEDIUM threat level",
            AntiDebugChecker.ThreatLevel.MEDIUM,
            result.threatLevel,
        )
    }

    @Test
    fun `ThreatLevel is NONE when no threats`() {
        val result =
            AntiDebugChecker.AntiDebugResult(
                isDebuggerAttached = false,
                isDebuggable = false,
                hasFridaIndicators = false,
                hasXposedIndicators = false,
                hasTracerPid = false,
                detectedThreats = emptyList(),
            )

        assertEquals(
            "No threats should result in NONE threat level",
            AntiDebugChecker.ThreatLevel.NONE,
            result.threatLevel,
        )
    }

    @Test
    fun `ThreatLevel enum values are correctly ordered`() {
        val levels = AntiDebugChecker.ThreatLevel.values()

        assertEquals("NONE should be first", AntiDebugChecker.ThreatLevel.NONE, levels[0])
        assertEquals("LOW should be second", AntiDebugChecker.ThreatLevel.LOW, levels[1])
        assertEquals("MEDIUM should be third", AntiDebugChecker.ThreatLevel.MEDIUM, levels[2])
        assertEquals("HIGH should be fourth", AntiDebugChecker.ThreatLevel.HIGH, levels[3])
        assertEquals("CRITICAL should be fifth", AntiDebugChecker.ThreatLevel.CRITICAL, levels[4])
    }
}
