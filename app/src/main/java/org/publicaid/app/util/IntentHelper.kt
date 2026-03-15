package org.publicaid.app.util

import android.content.Context
import android.content.Intent
import android.net.Uri

/** Android intents for call, navigate, share. */
object IntentHelper {

    /** Opens the phone dialer with the given number. */
    fun dial(context: Context, phone: String) {
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${phone.trim()}"))
        context.startActivity(intent)
    }

    /** Opens Google Maps navigation to the given coordinates. */
    fun navigate(context: Context, lat: Double, lng: Double, label: String? = null) {
        val uri = if (label != null) {
            Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(label)})")
        } else {
            Uri.parse("geo:$lat,$lng?q=$lat,$lng")
        }
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage("com.google.android.apps.maps")
        }
        // Fall back to any maps app if Google Maps isn't installed
        if (intent.resolveActivity(context.packageManager) != null) {
            context.startActivity(intent)
        } else {
            val fallback = Intent(Intent.ACTION_VIEW, uri)
            context.startActivity(fallback)
        }
    }

    /** Opens the system share sheet with entity name and URL. */
    fun share(context: Context, name: String, slug: String) {
        val url = "https://publicaid.org/entity/$slug"
        val text = "Check out $name on Publicaid: $url"
        val intent = Intent.createChooser(
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                putExtra(Intent.EXTRA_SUBJECT, name)
            },
            "Share via"
        )
        context.startActivity(intent)
    }

    /** Opens a URL in the browser. */
    fun openUrl(context: Context, url: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        context.startActivity(intent)
    }
}
