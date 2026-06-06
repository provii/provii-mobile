// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import timber.log.Timber
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Lifecycle-managed QR scanner composable with configurable throttling, torch control,
 * and accessibility live-region announcements. Handles camera permission requests, image
 * analysis via ML Kit barcode scanning, and automatic resource cleanup on lifecycle
 * events. Delegates to [ManagedBarcodeAnalyzer] for frame-rate-throttled QR detection.
 */
@Composable
fun ManagedQrScannerComponent(
    onQrScanned: (String) -> Unit,
    onError: (String) -> Unit,
    modifier: Modifier = Modifier,
    enableTorch: Boolean = false,
    scannerConfig: ScannerConfig = ScannerConfig(),
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val errorCameraPermissionText = stringResource(R.string.error_camera_permission_required)

    var cameraProvider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    var camera by remember { mutableStateOf<Camera?>(null) }
    var cameraExecutor by remember { mutableStateOf<ExecutorService?>(null) }
    var imageAnalyzer by remember { mutableStateOf<ImageAnalysis?>(null) }

    var hasCameraPermission by remember { mutableStateOf(false) }
    var isScanning by remember { mutableStateOf(true) }
    val isProcessing = remember { AtomicBoolean(false) }

    // Permission launcher
    val permissionLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted ->
            hasCameraPermission = granted
            if (!granted) {
                onError(errorCameraPermissionText)
            }
        }

    // Lifecycle observer to properly manage camera
    DisposableEffect(lifecycleOwner) {
        val observer =
            LifecycleEventObserver { _, event ->
                when (event) {
                    Lifecycle.Event.ON_PAUSE -> {
                        // Pause scanning when app goes to background
                        imageAnalyzer?.clearAnalyzer()
                    }
                    Lifecycle.Event.ON_RESUME -> {
                        // Resume scanning when app comes back
                        val executor = cameraExecutor
                        if (isScanning && executor != null) {
                            imageAnalyzer?.setAnalyzer(
                                executor,
                                ManagedBarcodeAnalyzer(
                                    scannerConfig,
                                    isProcessing,
                                ) { qrContent ->
                                    if (isScanning) {
                                        isScanning = false
                                        onQrScanned(qrContent)
                                    }
                                },
                            )
                        }
                    }
                    Lifecycle.Event.ON_DESTROY -> {
                        // Clean up resources
                        cleanupCamera(cameraProvider, cameraExecutor)
                    }
                    else -> {}
                }
            }

        lifecycleOwner.lifecycle.addObserver(observer)

        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    // Initialize camera executor
    LaunchedEffect(Unit) {
        cameraExecutor = Executors.newSingleThreadExecutor()
    }

    // Check permissions
    LaunchedEffect(Unit) {
        hasCameraPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

        if (!hasCameraPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    // Cleanup on disposal
    DisposableEffect(Unit) {
        onDispose {
            cleanupCamera(cameraProvider, cameraExecutor)
        }
    }

    // Update torch state
    LaunchedEffect(enableTorch, camera) {
        camera?.cameraControl?.enableTorch(enableTorch)
    }

    Box(modifier = modifier) {
        if (hasCameraPermission) {
            CameraPreview(
                onCameraProvider = { provider ->
                    cameraProvider = provider
                },
                onCamera = { cam ->
                    camera = cam
                },
                onImageAnalyzer = { analyzer ->
                    imageAnalyzer = analyzer
                },
                cameraExecutor = cameraExecutor,
                scannerConfig = scannerConfig,
                isProcessing = isProcessing,
                onQrDetected = { qrContent ->
                    if (isScanning) {
                        isScanning = false
                        onQrScanned(qrContent)
                    }
                },
                onError = onError,
            )

            // Scanning overlay
            if (isScanning) {
                ScanningOverlay()
            }
        } else {
            // No permission view
            NoPermissionView(
                onRequestPermission = {
                    permissionLauncher.launch(Manifest.permission.CAMERA)
                },
            )
        }
    }
}

@Composable
private fun CameraPreview(
    onCameraProvider: (ProcessCameraProvider) -> Unit,
    onCamera: (Camera) -> Unit,
    onImageAnalyzer: (ImageAnalysis) -> Unit,
    cameraExecutor: ExecutorService?,
    scannerConfig: ScannerConfig,
    isProcessing: AtomicBoolean,
    onQrDetected: (String) -> Unit,
    onError: (String) -> Unit,
) {
    val context = LocalContext.current
    val cameraResources = context.resources
    val lifecycleOwner = LocalLifecycleOwner.current
    val previewView = remember { PreviewView(context) }
    val cameraPreviewDescription = stringResource(R.string.qr_scanner_camera_preview)

    AndroidView(
        factory = { previewView },
        modifier =
            Modifier
                .fillMaxSize()
                .semantics {
                    contentDescription = cameraPreviewDescription
                },
    ) { view ->
        if (cameraExecutor == null) return@AndroidView

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                val provider = cameraProviderFuture.get()
                onCameraProvider(provider)

                // Unbind all use cases before rebinding
                provider.unbindAll()

                // Preview use case
                val preview =
                    Preview.Builder()
                        .setResolutionSelector(
                            ResolutionSelector.Builder()
                                .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
                                .build(),
                        )
                        .build()
                        .also {
                            it.setSurfaceProvider(view.surfaceProvider)
                        }

                // Image analysis use case
                val analyzer =
                    ImageAnalysis.Builder()
                        .setResolutionSelector(
                            ResolutionSelector.Builder()
                                .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
                                .build(),
                        )
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also {
                            it.setAnalyzer(
                                cameraExecutor,
                                ManagedBarcodeAnalyzer(scannerConfig, isProcessing, onQrDetected),
                            )
                        }

                onImageAnalyzer(analyzer)

                // Camera selector
                val cameraSelector =
                    CameraSelector.Builder()
                        .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                        .build()

                try {
                    // Bind use cases to lifecycle
                    val camera =
                        provider.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            preview,
                            analyzer,
                        )
                    onCamera(camera)

                    // Enable auto-focus
                    val cameraControl = camera.cameraControl
                    cameraControl.setLinearZoom(0f) // Reset zoom
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

private class ManagedBarcodeAnalyzer(
    private val config: ScannerConfig,
    private val isProcessing: AtomicBoolean,
    private val onQrDetected: (String) -> Unit,
) : ImageAnalysis.Analyzer {
    private val scanner = BarcodeScanning.getClient()
    private var lastProcessedTimestamp = 0L

    @androidx.camera.core.ExperimentalGetImage
    override fun analyze(imageProxy: ImageProxy) {
        // Skip if already processing
        if (isProcessing.get()) {
            imageProxy.close()
            return
        }

        // Throttle scanning
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastProcessedTimestamp < config.scanThrottleMs) {
            imageProxy.close()
            return
        }

        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            isProcessing.set(true)
            lastProcessedTimestamp = currentTime

            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

            scanner.process(image)
                .addOnSuccessListener { barcodes ->
                    for (barcode in barcodes) {
                        if (barcode.format == Barcode.FORMAT_QR_CODE) {
                            barcode.rawValue?.let { qrContent ->
                                if (qrContent.length <= config.maxQrSize) {
                                    onQrDetected(qrContent)
                                } else {
                                    Timber.w("QR code too large: ${qrContent.length} bytes")
                                }
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Timber.e(e, "QR code scanning failed")
                }
                .addOnCompleteListener {
                    isProcessing.set(false)
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }
}

@Composable
private fun ScanningOverlay() {
    val scanningStatusText = stringResource(R.string.qr_scanner_status_scanning)
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(32.dp)
                .semantics {
                    liveRegion = LiveRegionMode.Polite
                    contentDescription = scanningStatusText
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
                modifier = Modifier.padding(16.dp),
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun NoPermissionView(onRequestPermission: () -> Unit) {
    val accessibilityUiState = LocalAccessibilityUiState.current
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = stringResource(R.string.qr_scanner_camera_required),
            style = MaterialTheme.typography.headlineSmall,
        )
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            onClick = onRequestPermission,
            modifier = Modifier.heightIn(min = accessibilityUiState.minTouchTarget),
        ) {
            Text(stringResource(R.string.action_grant_permission))
        }
    }
}

private fun cleanupCamera(
    cameraProvider: ProcessCameraProvider?,
    cameraExecutor: ExecutorService?,
) {
    try {
        cameraProvider?.unbindAll()
        cameraExecutor?.shutdown()
        Timber.d("Camera resources cleaned up")
    } catch (e: Exception) {
        Timber.e(e, "Error cleaning up camera resources")
    }
}

data class ScannerConfig(
    val scanThrottleMs: Long = 500,
    val maxQrSize: Int = 10_000,
)
