package dev.inkora.inkora

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream
import java.nio.file.Files
import java.nio.file.attribute.PosixFilePermission
import com.google.common.collect.HashBiMap
import org.jsoup.Jsoup
import org.jsoup.parser.Parser
import org.junit.Assert.*
import org.junit.Test
import org.junit.rules.TemporaryFolder

/** Exercise the updated transitive APIs with bounded, credential-free fixtures. */
class DependencySecurityTest {
    @Test fun malformedTagNamesCannotBecomeActiveTemplates() {
        // Regression input from jsoup's upstream tag-normalization fix.
        val document = Jsoup.parse("<template\u001e><select><input>")
        assertEquals("template\u001e", document.body().child(0).normalName())
        assertTrue(document.select("template").isEmpty())
    }

    @Test fun nestedNamespacesPreserveEpubText() {
        val xml = buildString {
            for (i in 0 until 2000) append("<n$i:p xmlns:n$i='urn:$i'>")
            append("<leaf>L’excitation du livre</leaf>")
            for (i in 1999 downTo 0) append("</n$i:p>")
        }
        val document = Jsoup.parse(xml, "", Parser.xmlParser())
        assertEquals("L’excitation du livre", document.getElementsByTag("leaf").text())
    }

    @Test fun ordinaryGuavaCollectionsStillRoundTrip() {
        val original = HashBiMap.create<String, Int>().apply { put("first", 1); put("second", 2) }
        val bytes = ByteArrayOutputStream().apply {
            ObjectOutputStream(this).use { it.writeObject(original) }
        }.toByteArray()
        val restored = ObjectInputStream(ByteArrayInputStream(bytes)).use { it.readObject() }
        assertEquals(original, restored)
    }

    @Test fun junitTemporaryDirectoriesArePrivate() {
        val temporary = TemporaryFolder()
        temporary.create()
        try {
            val path = temporary.root.toPath()
            if (Files.getFileStore(path).supportsFileAttributeView("posix")) {
                val permissions = Files.getPosixFilePermissions(path)
                assertFalse(permissions.contains(PosixFilePermission.OTHERS_READ))
                assertFalse(permissions.contains(PosixFilePermission.GROUP_READ))
            }
        } finally { temporary.delete() }
    }
}
