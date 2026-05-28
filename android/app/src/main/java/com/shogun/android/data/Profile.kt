package com.shogun.android.data

import com.shogun.android.util.Defaults
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class Profile(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val sshHost: String = "",
    val sshPort: Int = Defaults.SSH_PORT,
    val sshUser: String = "",
    val sshKeyPath: String = "",
    val sshPassword: String = "",
    val projectPath: String = "",
    val shogunSession: String = Defaults.SHOGUN_SESSION,
    val agentsSession: String = Defaults.AGENTS_SESSION,
    val dashboardFileName: String = "dashboard.md"
)
