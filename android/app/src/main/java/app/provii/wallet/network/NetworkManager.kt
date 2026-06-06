// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import app.provii.wallet.R
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Queries Android ConnectivityManager to determine whether the device has a validated
 * internet connection and what transport type (Wi-Fi, cellular, ethernet) is active.
 * Used as a preflight check before network-dependent operations such as proving key
 * downloads and issuer API calls.
 */
@Singleton
class NetworkManager
    @Inject
    constructor() {
        fun isNetworkAvailable(context: Context): Boolean {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivityManager.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false

            return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        }

        fun getConnectionType(context: Context): String {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivityManager.activeNetwork ?: return context.getString(R.string.network_type_none)
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return context.getString(R.string.network_type_none)

            return when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> context.getString(R.string.network_type_wifi)
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> context.getString(R.string.network_type_cellular)
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> context.getString(R.string.network_type_ethernet)
                else -> context.getString(R.string.network_type_unknown)
            }
        }
    }
