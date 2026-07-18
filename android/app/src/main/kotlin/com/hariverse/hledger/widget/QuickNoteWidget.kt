package com.hariverse.hledger.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.*
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.cornerRadius
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import com.hariverse.hledger.MainActivity

class QuickNoteWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                QuickNoteWidgetContent(context, currentState())
            }
        }
    }

    @Composable
    private fun QuickNoteWidgetContent(context: Context, state: HomeWidgetGlanceState) {
        val prefs = state.preferences
        val recentNote = prefs.getString("recent_note", "") ?: ""
        val noteCount = prefs.getString("note_count", "0") ?: "0"

        val bgColor = ColorProvider(android.graphics.Color.parseColor("#13131A"))
        val surfaceColor = ColorProvider(android.graphics.Color.parseColor("#1C1C26"))
        val accentColor = ColorProvider(android.graphics.Color.parseColor("#6C63FF"))
        val yellowColor = ColorProvider(android.graphics.Color.parseColor("#F59E0B"))
        val textPrimary = ColorProvider(android.graphics.Color.parseColor("#FFFFFF"))
        val textSecondary = ColorProvider(android.graphics.Color.parseColor("#8B8FA8"))

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(bgColor)
                .cornerRadius(20.dp)
                .padding(14.dp)
                .clickable(actionStartActivity<MainActivity>()),
        ) {
            // Header
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "📝 Quick Note",
                    style = TextStyle(
                        color = yellowColor,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Spacer(modifier = GlanceModifier.defaultWeight())
                Text(
                    text = "$noteCount notes",
                    style = TextStyle(
                        color = textSecondary,
                        fontSize = 10.sp,
                    ),
                )
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            // Tap prompt
            Row(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .background(surfaceColor)
                    .cornerRadius(12.dp)
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "✏️",
                    style = TextStyle(fontSize = 16.sp),
                )
                Spacer(modifier = GlanceModifier.width(8.dp))
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Text(
                        text = "Tap to add a quick note",
                        style = TextStyle(
                            color = accentColor,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        ),
                    )
                    if (recentNote.isNotEmpty()) {
                        Spacer(modifier = GlanceModifier.height(4.dp))
                        Text(
                            text = "Last: $recentNote",
                            style = TextStyle(
                                color = textSecondary,
                                fontSize = 10.sp,
                            ),
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}
