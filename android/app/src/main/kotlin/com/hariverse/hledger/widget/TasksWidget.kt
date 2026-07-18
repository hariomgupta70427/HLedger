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

class TasksWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                TasksWidgetContent(context, currentState())
            }
        }
    }

    @Composable
    private fun TasksWidgetContent(context: Context, state: HomeWidgetGlanceState) {
        val prefs = state.preferences
        val pendingCount = prefs.getString("pending_tasks", "0") ?: "0"
        val completedCount = prefs.getString("completed_tasks", "0") ?: "0"
        val task1 = prefs.getString("task_1", "") ?: ""
        val task2 = prefs.getString("task_2", "") ?: ""
        val task3 = prefs.getString("task_3", "") ?: ""
        val task4 = prefs.getString("task_4", "") ?: ""
        val task5 = prefs.getString("task_5", "") ?: ""
        val taskPri1 = prefs.getString("task_pri_1", "low") ?: "low"
        val taskPri2 = prefs.getString("task_pri_2", "low") ?: "low"
        val taskPri3 = prefs.getString("task_pri_3", "low") ?: "low"
        val taskPri4 = prefs.getString("task_pri_4", "low") ?: "low"
        val taskPri5 = prefs.getString("task_pri_5", "low") ?: "low"

        val bgColor = ColorProvider(android.graphics.Color.parseColor("#13131A"))
        val surfaceColor = ColorProvider(android.graphics.Color.parseColor("#1C1C26"))
        val accentColor = ColorProvider(android.graphics.Color.parseColor("#6C63FF"))
        val greenColor = ColorProvider(android.graphics.Color.parseColor("#00D68F"))
        val yellowColor = ColorProvider(android.graphics.Color.parseColor("#F59E0B"))
        val redColor = ColorProvider(android.graphics.Color.parseColor("#FF4757"))
        val textPrimary = ColorProvider(android.graphics.Color.parseColor("#FFFFFF"))
        val textSecondary = ColorProvider(android.graphics.Color.parseColor("#8B8FA8"))

        fun priorityColor(pri: String): ColorProvider = when (pri) {
            "high" -> redColor
            "medium" -> accentColor
            else -> textSecondary
        }

        fun priorityDot(pri: String): String = when (pri) {
            "high" -> "🔴"
            "medium" -> "🟣"
            else -> "⚪"
        }

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(bgColor)
                .cornerRadius(20.dp)
                .padding(16.dp)
                .clickable(actionStartActivity<MainActivity>()),
        ) {
            // Header
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "📋 Tasks",
                    style = TextStyle(
                        color = accentColor,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Spacer(modifier = GlanceModifier.defaultWeight())
                Text(
                    text = "$pendingCount pending",
                    style = TextStyle(
                        color = yellowColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                    ),
                )
            }

            Spacer(modifier = GlanceModifier.height(8.dp))

            // Stats
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Column(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .background(surfaceColor)
                        .cornerRadius(10.dp)
                        .padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = pendingCount,
                        style = TextStyle(
                            color = yellowColor,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                    Text(
                        text = "Pending",
                        style = TextStyle(color = textSecondary, fontSize = 10.sp),
                    )
                }
                Spacer(modifier = GlanceModifier.width(8.dp))
                Column(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .background(surfaceColor)
                        .cornerRadius(10.dp)
                        .padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = completedCount,
                        style = TextStyle(
                            color = greenColor,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                    Text(
                        text = "Done",
                        style = TextStyle(color = textSecondary, fontSize = 10.sp),
                    )
                }
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            // Task list
            val tasks = listOf(
                task1 to taskPri1,
                task2 to taskPri2,
                task3 to taskPri3,
                task4 to taskPri4,
                task5 to taskPri5,
            ).filter { it.first.isNotEmpty() }

            for ((task, pri) in tasks) {
                Row(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = priorityDot(pri),
                        style = TextStyle(fontSize = 8.sp),
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Text(
                        text = task,
                        style = TextStyle(color = textPrimary, fontSize = 12.sp),
                        maxLines = 1,
                    )
                }
            }

            if (tasks.isEmpty()) {
                Spacer(modifier = GlanceModifier.height(8.dp))
                Text(
                    text = "✅ All tasks done!",
                    style = TextStyle(
                        color = greenColor,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                    ),
                )
            }
        }
    }
}
