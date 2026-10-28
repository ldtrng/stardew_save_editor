package io.ld2t.stardew_save_editor

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.FlutterInjector
import io.flutter.plugins.googlemobileads.NativeAdFactory

/**
 * Native ad layouts styled by the app. Every chrome element has a fixed size in
 * dp (text in dp too, so the system font scale can't change it), which makes the
 * height predictable on every device:
 *  - small: [SMALL_HEIGHT_DP] in total;
 *  - medium: [MEDIUM_CHROME_DP] plus a media view that takes whatever height
 *    Flutter gives the platform view, so extra or missing dp never clips the
 *    text or the install button.
 * Colours come from Dart through customOptions (bg, text, muted, cta, ctaText).
 */
class SvNativeAdFactory(private val context: Context, private val medium: Boolean) : NativeAdFactory {
    companion object {
        const val SMALL_HEIGHT_DP = 92
        const val MEDIUM_CHROME_DP = 146
    }

    private val density = context.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density + 0.5f).toInt()

    private val face: Typeface? by lazy {
        try {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/fonts/PixelifySans.ttf")
            Typeface.createFromAsset(context.assets, key)
        } catch (_: Exception) {
            null
        }
    }

    private class Colors(private val opts: Map<String, Any>?) {
        private fun c(key: String, def: Int) = (opts?.get(key) as? Number)?.toInt() ?: def
        val bg = c("bg", Color.WHITE)
        val text = c("text", Color.BLACK)
        val muted = c("muted", Color.GRAY)
        val cta = c("cta", Color.DKGRAY)
        val ctaText = c("ctaText", Color.WHITE)
    }

    private fun label(sizeDp: Float, color: Int, bold: Boolean = false, lines: Int = 1) = TextView(context).apply {
        setTextSize(TypedValue.COMPLEX_UNIT_DIP, sizeDp)
        setTextColor(color)
        typeface = if (bold) Typeface.create(face ?: Typeface.DEFAULT, Typeface.BOLD) else (face ?: Typeface.DEFAULT)
        maxLines = lines
        ellipsize = TextUtils.TruncateAt.END
        includeFontPadding = false
        gravity = Gravity.CENTER_VERTICAL or Gravity.START
    }

    private fun badge(c: Colors) = label(10f, c.cta, bold = true).apply {
        text = "Ad"
        gravity = Gravity.CENTER
        setPadding(dp(4), 0, dp(4), 0)
        background = GradientDrawable().apply {
            setColor(Color.TRANSPARENT)
            setStroke(dp(1), c.cta)
            cornerRadius = dp(3).toFloat()
        }
    }

    private fun cta(c: Colors, heightDp: Int) = label(14f, c.ctaText, bold = true).apply {
        gravity = Gravity.CENTER
        setBackgroundColor(c.cta)
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(heightDp))
    }

    /** Headline + "Ad" badge with rating/advertiser line; shared by both sizes. */
    private fun titleBlock(c: Colors, headline: TextView, badgeRow: LinearLayout): LinearLayout =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            addView(headline, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(20)))
            addView(badgeRow, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(18)))
        }

    override fun createNativeAd(nativeAd: NativeAd, customOptions: Map<String, Any>?): NativeAdView {
        val c = Colors(customOptions)
        val view = NativeAdView(context)

        val headline = label(15f, c.text, bold = true).apply { text = nativeAd.headline ?: "" }
        val rating = label(12f, c.muted)
        val stars = nativeAd.starRating
        rating.text = when {
            stars != null -> "★ %.1f".format(stars)
            !nativeAd.advertiser.isNullOrEmpty() -> nativeAd.advertiser
            else -> ""
        }
        val badgeRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(badge(c), LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(14)).apply { marginEnd = dp(6) })
            addView(rating, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f))
        }
        val title = titleBlock(c, headline, badgeRow)

        val icon = ImageView(context).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            val d = nativeAd.icon?.drawable
            if (d != null) setImageDrawable(d) else visibility = View.GONE
        }
        val install = cta(c, if (medium) 36 else 32).apply {
            text = nativeAd.callToAction ?: ""
            if (nativeAd.callToAction == null) visibility = View.INVISIBLE
        }

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(c.bg)
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }

        if (medium) {
            val media = MediaView(context).apply { setImageScaleType(ImageView.ScaleType.FIT_CENTER) }
            view.mediaView = media
            root.addView(media, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f).apply { bottomMargin = dp(8) })

            val header = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(icon, LinearLayout.LayoutParams(dp(40), dp(40)).apply { marginEnd = dp(10) })
                addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            }
            root.addView(header, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(40)))

            val body = label(12f, c.muted, lines = 2).apply {
                text = nativeAd.body ?: ""
                gravity = Gravity.TOP or Gravity.START
            }
            view.bodyView = body
            root.addView(body, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(32)).apply { topMargin = dp(6) })
            root.addView(install, (install.layoutParams as LinearLayout.LayoutParams).apply { topMargin = dp(8) })
        } else {
            val row = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(icon, LinearLayout.LayoutParams(dp(64), dp(64)).apply { marginEnd = dp(10) })
                val column = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(title, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(38)))
                    addView(install, (install.layoutParams as LinearLayout.LayoutParams).apply { topMargin = dp(6) })
                }
                addView(column, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            }
            root.addView(row, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT))
        }

        view.addView(root, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        view.headlineView = headline
        view.iconView = icon
        view.callToActionView = install
        view.starRatingView = rating
        view.setNativeAd(nativeAd)
        return view
    }
}
