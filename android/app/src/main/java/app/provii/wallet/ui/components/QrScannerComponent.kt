// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import kotlinx.coroutines.launch
import timber.log.Timber
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Simplified QR scanner composable for one-shot code scanning. Manages camera permissions,
 * CameraX preview binding, and ML Kit barcode analysis. Provides live-region status
 * announcements for TalkBack users and enforces the platform minimum 48dp touch target
 * for the permission-request button.
 */
@Composable
fun QrScannerComponent(
    onQrScanned: (String) -> Unit,
    onError: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }
    val accessibilityUiState = LocalAccessibilityUiState.current

    val errorCameraPermissionText = stringResource(R.string.error_camera_permission_required)
    val statusScanningText = stringResource(R.string.qr_scanner_status_scanning)
    val requestingPermissionText = stringResource(R.string.qr_scanner_requesting_permission)

    var hasCameraPermission by remember { mutableStateOf(false) }
    var isScanning by remember { mutableStateOf(true) }

    // State announcement helper for accessibility
    var statusAnnouncement by remember { mutableStateOf("") }

    // Permission launcher
    val permissionLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted ->
            hasCameraPermission = granted
            if (!granted) {
                statusAnnouncement = errorCameraPermissionText
                onError(errorCameraPermissionText)
            } else {
                statusAnnouncement = statusScanningText
            }
        }

    // Check initial permission state
    LaunchedEffect(Unit) {
        hasCameraPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

        if (!hasCameraPermission) {
            statusAnnouncement = requestingPermissionText
            permissionLauncher.launch(Manifest.permission.CAMERA)
        } else {
            statusAnnouncement = statusScanningText
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            cameraExecutor.shutdown()
        }
    }

    Box(modifier = modifier) {
        if (hasCameraPermission) {
            CameraPreview(
                lifecycleOwner = lifecycleOwner,
                cameraExecutor = cameraExecutor,
                onQrDetected = { qrContent ->
                    if (isScanning) {
                        isScanning = false
                        onQrScanned(qrContent)
                    }
                },
                onError = onError,
            )

            // Scanning overlay with live region for accessibility
            if (isScanning) {
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(32.dp)
                            .semantics {
                                liveRegion = LiveRegionMode.Polite
                                contentDescription = statusScanningText
                            },
                    contentAlignment = Alignment.Center,
                ) {
                    Card(
                        colors =
                            CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.8f),
                            ),
                    ) {
                        Text(
                            text = stringResource(R.string.qr_scanner_scanning),
                            modifier =
                                Modifier
                                    .padding(16.dp)
                                    .semantics {
                                        liveRegion = LiveRegionMode.Polite
                                    },
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }

            // Status announcement for state changes
            if (statusAnnouncement.isNotEmpty()) {
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .semantics {
                                liveRegion = LiveRegionMode.Assertive
                                contentDescription = statusAnnouncement
                            },
                )
            }
        } else {
            // No permission view
            Column(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .semantics {
                            liveRegion = LiveRegionMode.Polite
                        },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = stringResource(R.string.qr_scanner_camera_required),
                    style = MaterialTheme.typography.headlineSmall,
                    modifier =
                        Modifier.semantics {
                            liveRegion = LiveRegionMode.Assertive
                        },
                )
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = {
                        statusAnnouncement = requestingPermissionText
                        permissionLauncher.launch(Manifest.permission.CAMERA)
                    },
                    modifier = Modifier.heightIn(min = accessibilityUiState.minTouchTarget),
                ) {
                    Text(stringResource(R.string.action_grant_permission))
                }
            }
        }
    }
}

@Composable
private fun CameraPreview(
    lifecycleOwner: androidx.lifecycle.LifecycleOwner,
    cameraExecutor: ExecutorService,
    onQrDetected: (String) -> Unit,
    onError: (String) -> Unit,
) {
    val context = LocalContext.current
    val cameraResources = context.resources
    val previewView = remember { PreviewView(context) }
    val cameraPreviewDescription = stringResource(R.string.qr_scanner_camera_preview)

    AndroidView(
        factory = { previewView },
        modifier =
            Modifier
                .fillMaxSize()
                .semantics {
                    contentDescription = cameraPreviewDescription
                    role = Role.Image
                },
    ) { view ->
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()

                val preview =
                    Preview.Builder().build().also {
                        it.setSurfaceProvider(view.surfaceProvider)
                    }

                val imageAnalyzer =
                    ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also {
                            it.setAnalyzer(
                                cameraExecutor,
                                BarcodeAnalyzer { qrContent ->
                                    onQrDetected(qrContent)
                                },
                            )
                        }

                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview,
                        imageAnalyzer,
                    )
                } catch (e: Exception) {
                    Timber.e(e, "Failed to bind camera use cases")
                    onError(cameraResources.getString(R.string.error_camera_start_failed, e.localizedMessage ?: ""))
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to get camera provider")
                onError(cameraResources.getString(R.string.error_camera_init_failed, e.localizedMessage ?: ""))
            }
        }, ContextCompat.getMainExecutor(context))
    }
}

private class BarcodeAnalyzer(
    private val onQrDetected: (String) -> Unit,
) : ImageAnalysis.Analyzer {
    private val scanner = BarcodeScanning.getClient()

    @androidx.camera.core.ExperimentalGetImage
    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

            scanner.process(image)
                .addOnSuccessListener { barcodes ->
                    for (barcode in barcodes) {
                        if (barcode.format == Barcode.FORMAT_QR_CODE) {
                            barcode.rawValue?.let { qrContent ->
                                onQrDetected(qrContent)
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Timber.e(e, "QR code scanning failed")
                }
                .addOnCompleteListener {
                    imageProxy.close()
                }
        }
    }
}
