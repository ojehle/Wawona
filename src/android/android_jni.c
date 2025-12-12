/**
 * Android JNI Bridge for Wawona Wayland Compositor
 * 
 * This file provides the Java Native Interface (JNI) bridge between the Android
 * application layer and the Wawona compositor. It handles Vulkan surface creation,
 * safe area detection, and iOS settings compatibility.
 * 
 * Features:
 * - Vulkan rendering with hardware acceleration
 * - Android WindowInsets integration for safe area support
 * - iOS settings 1:1 mapping
 * - Thread-safe initialization and cleanup
 */

#include <jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_android.h>
#include "WawonaSettings.h"

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "WawonaJNI", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "WawonaJNI", __VA_ARGS__)

// JNI Function Prototypes
JNIEXPORT void JNICALL Java_com_aspauldingcode_wawona_WawonaNative_nativeInit(JNIEnv* env, jobject thiz);
JNIEXPORT void JNICALL Java_com_aspauldingcode_wawona_WawonaNative_nativeSetSurface(JNIEnv* env, jobject thiz, jobject surface);
JNIEXPORT void JNICALL Java_com_aspauldingcode_wawona_WawonaNative_nativeDestroySurface(JNIEnv* env, jobject thiz);
JNIEXPORT void JNICALL Java_com_aspauldingcode_wawona_WawonaNative_nativeUpdateSafeArea(JNIEnv* env, jobject thiz, jint left, jint top, jint right, jint bottom);
JNIEXPORT void JNICALL Java_com_aspauldingcode_wawona_WawonaNative_nativeApplySettings(JNIEnv* env, jobject thiz,
                                                                jboolean forceServerSideDecorations,
                                                                jboolean autoRetinaScaling,
                                                                jint renderingBackend,
                                                                jboolean respectSafeArea,
                                                                jboolean renderMacOSPointer,
                                                                jboolean swapCmdAsCtrl,
                                                                jboolean universalClipboard,
                                                                jboolean colorSyncSupport,
                                                                jboolean nestedCompositorsSupport,
                                                                jboolean useMetal4ForNested,
                                                                jboolean multipleClients,
                                                                jboolean waypipeRSSupport,
                                                                jboolean enableTCPListener,
                                                                jint tcpPort);

// ============================================================================
// Global State
// ============================================================================

// Vulkan resources
VkInstance g_instance = VK_NULL_HANDLE;
VkPhysicalDevice g_physicalDevice = VK_NULL_HANDLE;
VkSurfaceKHR g_surface = VK_NULL_HANDLE;
VkDevice g_device = VK_NULL_HANDLE;
VkQueue g_queue = VK_NULL_HANDLE;
VkSwapchainKHR g_swapchain = VK_NULL_HANDLE;
uint32_t g_queue_family = 0;
ANativeWindow* g_window = NULL;

// Threading
static int g_running = 0;
static pthread_t g_render_thread = 0;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

// Safe area support (for display cutouts, notches, etc.)
static int g_safeAreaLeft = 0;
static int g_safeAreaTop = 0;
static int g_safeAreaRight = 0;
static int g_safeAreaBottom = 0;

// Raw safe area values from Android (independent of setting)
static int g_rawSafeAreaLeft = 0;
static int g_rawSafeAreaTop = 0;
static int g_rawSafeAreaRight = 0;
static int g_rawSafeAreaBottom = 0;

// iOS Settings 1:1 mapping (for compatibility with iOS version)
// Now managed by WawonaSettings.c via WawonaSettings_UpdateConfig

// ============================================================================
// Safe Area Detection
// ============================================================================

/**
 * Update safe area insets from Android WindowInsets API
 * Handles display cutouts (notches, punch holes) and system gesture insets
 */
static void update_safe_area(JNIEnv* env, jobject activity) {
    LOGI("update_safe_area called");
    if (!activity) {
        LOGE("update_safe_area: activity is NULL");
        g_safeAreaLeft = 0;
        g_safeAreaTop = 0;
        g_safeAreaRight = 0;
        g_safeAreaBottom = 0;
        return;
    }
    if (!WawonaSettings_GetRespectSafeArea()) {
        LOGI("Safe area respect disabled, setting to 0");
        g_safeAreaLeft = 0;
        g_safeAreaTop = 0;
        g_safeAreaRight = 0;
        g_safeAreaBottom = 0;
        return;
    }
    LOGI("Updating safe area from WindowInsets...");
    
    // Get WindowInsets
    jclass activityClass = (*env)->GetObjectClass(env, activity);
    jmethodID getWindowMethod = (*env)->GetMethodID(env, activityClass, "getWindow", "()Landroid/view/Window;");
    jobject window = (*env)->CallObjectMethod(env, activity, getWindowMethod);
    
    if (window) {
        jclass windowClass = (*env)->GetObjectClass(env, window);
        jmethodID getDecorViewMethod = (*env)->GetMethodID(env, windowClass, "getDecorView", "()Landroid/view/View;");
        jobject decorView = (*env)->CallObjectMethod(env, window, getDecorViewMethod);
        
        if (decorView) {
            // Get root window insets
            jclass viewClass = (*env)->GetObjectClass(env, decorView);
            jmethodID getRootWindowInsetsMethod = (*env)->GetMethodID(env, viewClass, "getRootWindowInsets", "()Landroid/view/WindowInsets;");
            jobject windowInsets = (*env)->CallObjectMethod(env, decorView, getRootWindowInsetsMethod);
            
            if (windowInsets) {
                // Get display cutout for notch/punch hole
                jclass windowInsetsClass = (*env)->GetObjectClass(env, windowInsets);
                jmethodID getDisplayCutoutMethod = (*env)->GetMethodID(env, windowInsetsClass, "getDisplayCutout", "()Landroid/view/DisplayCutout;");
                jobject displayCutout = (*env)->CallObjectMethod(env, windowInsets, getDisplayCutoutMethod);
                
                if (displayCutout) {
                    jclass displayCutoutClass = (*env)->GetObjectClass(env, displayCutout);
                    
                    // Get safe insets
                    jmethodID getSafeInsetLeftMethod = (*env)->GetMethodID(env, displayCutoutClass, "getSafeInsetLeft", "()I");
                    jmethodID getSafeInsetTopMethod = (*env)->GetMethodID(env, displayCutoutClass, "getSafeInsetTop", "()I");
                    jmethodID getSafeInsetRightMethod = (*env)->GetMethodID(env, displayCutoutClass, "getSafeInsetRight", "()I");
                    jmethodID getSafeInsetBottomMethod = (*env)->GetMethodID(env, displayCutoutClass, "getSafeInsetBottom", "()I");
                    
                    g_safeAreaLeft = (*env)->CallIntMethod(env, displayCutout, getSafeInsetLeftMethod);
                    g_safeAreaTop = (*env)->CallIntMethod(env, displayCutout, getSafeInsetTopMethod);
                    g_safeAreaRight = (*env)->CallIntMethod(env, displayCutout, getSafeInsetRightMethod);
                    g_safeAreaBottom = (*env)->CallIntMethod(env, displayCutout, getSafeInsetBottomMethod);
                    
                    LOGI("Safe area updated: left=%d, top=%d, right=%d, bottom=%d", 
                         g_safeAreaLeft, g_safeAreaTop, g_safeAreaRight, g_safeAreaBottom);
                    
                    (*env)->DeleteLocalRef(env, displayCutout);
                } else {
                    // Fallback to system gesture insets for navigation bar
                    jmethodID getSystemGestureInsetsMethod = (*env)->GetMethodID(env, windowInsetsClass, "getSystemGestureInsets", "()Landroid/graphics/Insets;");
                    jobject systemGestureInsets = (*env)->CallObjectMethod(env, windowInsets, getSystemGestureInsetsMethod);
                    
                    if (systemGestureInsets) {
                        jclass insetsClass = (*env)->GetObjectClass(env, systemGestureInsets);
                        jfieldID leftField = (*env)->GetFieldID(env, insetsClass, "left", "I");
                        jfieldID topField = (*env)->GetFieldID(env, insetsClass, "top", "I");
                        jfieldID rightField = (*env)->GetFieldID(env, insetsClass, "right", "I");
                        jfieldID bottomField = (*env)->GetFieldID(env, insetsClass, "bottom", "I");
                        
                        g_safeAreaLeft = (*env)->GetIntField(env, systemGestureInsets, leftField);
                        g_safeAreaTop = (*env)->GetIntField(env, systemGestureInsets, topField);
                        g_safeAreaRight = (*env)->GetIntField(env, systemGestureInsets, rightField);
                        g_safeAreaBottom = (*env)->GetIntField(env, systemGestureInsets, bottomField);
                        
                        LOGI("System gesture insets: left=%d, top=%d, right=%d, bottom=%d", 
                             g_safeAreaLeft, g_safeAreaTop, g_safeAreaRight, g_safeAreaBottom);
                        
                        (*env)->DeleteLocalRef(env, systemGestureInsets);
                    } else {
                        // Default to no safe area
                        g_safeAreaLeft = 0;
                        g_safeAreaTop = 0;
                        g_safeAreaRight = 0;
                        g_safeAreaBottom = 0;
                        LOGI("No safe area detected, using full screen");
                    }
                }
                
                (*env)->DeleteLocalRef(env, windowInsets);
            }
            
            (*env)->DeleteLocalRef(env, decorView);
        }
        
        (*env)->DeleteLocalRef(env, window);
    }
    
    (*env)->DeleteLocalRef(env, activityClass);
}

// ============================================================================
// Vulkan Initialization
// ============================================================================

/**
 * Create Vulkan instance with Android surface extensions
 */
static VkResult create_instance(void) {
    // Set ICD before creating instance based on rendering backend setting
    // If Waypipe support is enabled, force SwiftShader for compatibility
    if (WawonaSettings_GetWaypipeRSSupportEnabled()) {
        LOGI("Waypipe support enabled: Forcing SwiftShader ICD");
        setenv("VK_ICD_FILENAMES", "/system/etc/vulkan/icd.d/swiftshader_icd.json", 1);
    } else {
        switch (WawonaSettings_GetRenderingBackend()) {
            case 1: // Metal (Vulkan)
                setenv("VK_ICD_FILENAMES", "/data/local/tmp/freedreno_icd.json", 1);
                break;
            case 2: // Cocoa (Surface) - use software rendering (SwiftShader)
                LOGI("Rendering backend 'Cocoa' selected: Using SwiftShader ICD");
                setenv("VK_ICD_FILENAMES", "/system/etc/vulkan/icd.d/swiftshader_icd.json", 1);
                break;
            case 0: // Automatic - default to Vulkan with fallback
            default:
                setenv("VK_ICD_FILENAMES", "/data/local/tmp/freedreno_icd.json", 1);
                break;
        }
    }
    
    const char* exts[] = {
        VK_KHR_SURFACE_EXTENSION_NAME,
        VK_KHR_ANDROID_SURFACE_EXTENSION_NAME
    };
    VkApplicationInfo app = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO };
    app.pApplicationName = "Wawona";
    app.applicationVersion = VK_MAKE_VERSION(0,0,1);
    app.pEngineName = "Wawona";
    app.engineVersion = VK_MAKE_VERSION(0,0,1);
    app.apiVersion = VK_API_VERSION_1_0;

    VkInstanceCreateInfo ci = { .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO };
    ci.pApplicationInfo = &app;
    ci.enabledExtensionCount = (uint32_t)(sizeof(exts)/sizeof(exts[0]));
    ci.ppEnabledExtensionNames = exts;
    
    VkResult res = vkCreateInstance(&ci, NULL, &g_instance);
    if (res != VK_SUCCESS) {
        LOGE("vkCreateInstance failed: %d", res);
        // Try SwiftShader fallback
        setenv("VK_ICD_FILENAMES", "/system/etc/vulkan/icd.d/swiftshader_icd.json", 1);
        res = vkCreateInstance(&ci, NULL, &g_instance);
    }
    if (res != VK_SUCCESS) LOGE("vkCreateInstance failed: %d", res);
    return res;
}

/**
 * Pick the first available Vulkan physical device
 */
static VkPhysicalDevice pick_device(void) {
    uint32_t count = 0; 
    VkResult res = vkEnumeratePhysicalDevices(g_instance, &count, NULL);
    if (res != VK_SUCCESS || count == 0) {
        LOGE("vkEnumeratePhysicalDevices failed: %d, count=%u", res, count);
        return VK_NULL_HANDLE;
    }
    VkPhysicalDevice devs[4]; 
    if (count > 4) count = 4; 
    res = vkEnumeratePhysicalDevices(g_instance, &count, devs);
    if (res != VK_SUCCESS) {
        LOGE("vkEnumeratePhysicalDevices failed: %d", res);
        return VK_NULL_HANDLE;
    }
    LOGI("Found %u Vulkan devices", count);
    
    // Print device names
    for (uint32_t i = 0; i < count; i++) {
        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(devs[i], &props);
        LOGI("Device %u: %s (Type: %d, API: %u.%u.%u)", 
             i, props.deviceName, props.deviceType,
             VK_VERSION_MAJOR(props.apiVersion),
             VK_VERSION_MINOR(props.apiVersion),
             VK_VERSION_PATCH(props.apiVersion));
    }
    
    g_physicalDevice = devs[0];
    return devs[0];
}

/**
 * Find a queue family that supports graphics and surface presentation
 */
static int pick_queue_family(VkPhysicalDevice pd) {
    uint32_t count = 0; 
    vkGetPhysicalDeviceQueueFamilyProperties(pd, &count, NULL);
    if (count == 0) return -1;
    
    VkQueueFamilyProperties props[8]; 
    if (count > 8) count = 8; 
    vkGetPhysicalDeviceQueueFamilyProperties(pd, &count, props);
    
    for (uint32_t i = 0; i < count; i++) {
        VkBool32 sup = VK_FALSE; 
        vkGetPhysicalDeviceSurfaceSupportKHR(pd, i, g_surface, &sup);
        if ((props[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) && sup) {
            LOGI("Found graphics queue family %u", i);
            return (int)i;
        }
    }
    LOGE("No graphics queue family found");
    return -1;
}

/**
 * Check if an extension is available in the list
 */
static int is_extension_available(const char* name, VkExtensionProperties* props, uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        if (strcmp(name, props[i].extensionName) == 0) {
            return 1;
        }
    }
    return 0;
}

/**
 * Create Vulkan logical device with swapchain extension
 */
static int create_device(VkPhysicalDevice pd) {
    int q = pick_queue_family(pd); 
    if (q < 0) return -1; 
    g_queue_family = (uint32_t)q;
    
    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci = { .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO };
    qci.queueFamilyIndex = g_queue_family; 
    qci.queueCount = 1; 
    qci.pQueuePriorities = &prio;
    
    // Check available extensions
    uint32_t extCount = 0;
    vkEnumerateDeviceExtensionProperties(pd, NULL, &extCount, NULL);
    VkExtensionProperties* availableExts = malloc(sizeof(VkExtensionProperties) * extCount);
    if (availableExts) {
        vkEnumerateDeviceExtensionProperties(pd, NULL, &extCount, availableExts);
    }
    
    // List of desired extensions
    const char* desired_exts[] = { 
        VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME,
        VK_KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME,
        "VK_EXT_external_memory_dma_buf", // Explicit string if header missing
        "VK_ANDROID_external_memory_android_hardware_buffer"
    };
    uint32_t desiredCount = sizeof(desired_exts)/sizeof(desired_exts[0]);
    
    // Filter enabled extensions
    const char* enabled_exts[16];
    uint32_t enabledCount = 0;
    
    for (uint32_t i = 0; i < desiredCount; i++) {
        if (availableExts && is_extension_available(desired_exts[i], availableExts, extCount)) {
            enabled_exts[enabledCount++] = desired_exts[i];
            LOGI("Enabling extension: %s", desired_exts[i]);
        } else {
            LOGI("Extension not available (skipping): %s", desired_exts[i]);
        }
    }
    
    if (availableExts) free(availableExts);
    
    VkDeviceCreateInfo dci = { .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO };
    dci.queueCreateInfoCount = 1; 
    dci.pQueueCreateInfos = &qci;
    dci.enabledExtensionCount = enabledCount;
    dci.ppEnabledExtensionNames = enabled_exts;
    
    if (vkCreateDevice(pd, &dci, NULL, &g_device) != VK_SUCCESS) {
        LOGE("vkCreateDevice failed");
        return -1;
    }
    vkGetDeviceQueue(g_device, g_queue_family, 0, &g_queue);
    LOGI("Device created successfully");
    return 0;
}

/**
 * Create swapchain for surface presentation
 */
static int create_swapchain(VkPhysicalDevice pd) {
    VkSurfaceCapabilitiesKHR caps; 
    VkResult res = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pd, g_surface, &caps);
    if (res != VK_SUCCESS) {
        LOGE("vkGetPhysicalDeviceSurfaceCapabilitiesKHR failed: %d", res);
        return -1;
    }
    
    VkExtent2D ext = caps.currentExtent; 
    if (ext.width == 0 || ext.height == 0) ext = (VkExtent2D){ 640, 480 };
    LOGI("Swapchain extent: %ux%u", ext.width, ext.height);
    
    VkSwapchainCreateInfoKHR sci = { .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR };
    sci.surface = g_surface; 
    sci.minImageCount = caps.minImageCount > 2 ? caps.minImageCount : 2;
    sci.imageFormat = VK_FORMAT_R8G8B8A8_UNORM; 
    sci.imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
    sci.imageExtent = ext; 
    sci.imageArrayLayers = 1; 
    sci.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    sci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE; 
    sci.preTransform = caps.currentTransform;
    sci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR; 
    sci.presentMode = VK_PRESENT_MODE_FIFO_KHR;
    sci.clipped = VK_TRUE;
    
    if (vkCreateSwapchainKHR(g_device, &sci, NULL, &g_swapchain) != VK_SUCCESS) {
        LOGE("vkCreateSwapchainKHR failed");
        return -1;
    }
    LOGI("Swapchain created successfully");
    return 0;
}

// ============================================================================
// Rendering
// ============================================================================

static VkImageView* g_imageViews = NULL;
static VkFramebuffer* g_framebuffers = NULL;
static VkRenderPass g_renderPass = VK_NULL_HANDLE;
static uint32_t g_swapchainImageCount = 0;

/**
 * Create Image Views
 */
static int create_image_views(uint32_t imageCount, VkImage* images) {
    if (g_imageViews) free(g_imageViews);
    g_imageViews = malloc(imageCount * sizeof(VkImageView));
    g_swapchainImageCount = imageCount;
    for (uint32_t i = 0; i < imageCount; i++) {
        VkImageViewCreateInfo ivci = { .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO };
        ivci.image = images[i];
        ivci.viewType = VK_IMAGE_VIEW_TYPE_2D;
        ivci.format = VK_FORMAT_R8G8B8A8_UNORM; // Must match swapchain format
        ivci.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
        ivci.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
        ivci.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
        ivci.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;
        ivci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        ivci.subresourceRange.baseMipLevel = 0;
        ivci.subresourceRange.levelCount = 1;
        ivci.subresourceRange.baseArrayLayer = 0;
        ivci.subresourceRange.layerCount = 1;
        
        if (vkCreateImageView(g_device, &ivci, NULL, &g_imageViews[i]) != VK_SUCCESS) {
            LOGE("Failed to create image view %u", i);
            return -1;
        }
    }
    return 0;
}

/**
 * Create Render Pass
 */
static int create_render_pass(void) {
    if (g_renderPass != VK_NULL_HANDLE) vkDestroyRenderPass(g_device, g_renderPass, NULL);

    VkAttachmentDescription colorAttachment = {0};
    colorAttachment.format = VK_FORMAT_R8G8B8A8_UNORM;
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR; // Clear to background (Dark Blue)
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference colorAttachmentRef = {0};
    colorAttachmentRef.attachment = 0;
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkSubpassDescription subpass = {0};
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;

    VkSubpassDependency dependency = {0};
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.srcAccessMask = 0;
    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    VkRenderPassCreateInfo renderPassInfo = { .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO };
    renderPassInfo.attachmentCount = 1;
    renderPassInfo.pAttachments = &colorAttachment;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;
    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    if (vkCreateRenderPass(g_device, &renderPassInfo, NULL, &g_renderPass) != VK_SUCCESS) {
        LOGE("Failed to create render pass");
        return -1;
    }
    return 0;
}

/**
 * Create Framebuffers
 */
static int create_framebuffers(uint32_t imageCount, VkExtent2D extent) {
    if (g_framebuffers) free(g_framebuffers);
    g_framebuffers = malloc(imageCount * sizeof(VkFramebuffer));
    for (uint32_t i = 0; i < imageCount; i++) {
        VkImageView attachments[] = { g_imageViews[i] };

        VkFramebufferCreateInfo framebufferInfo = { .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO };
        framebufferInfo.renderPass = g_renderPass;
        framebufferInfo.attachmentCount = 1;
        framebufferInfo.pAttachments = attachments;
        framebufferInfo.width = extent.width;
        framebufferInfo.height = extent.height;
        framebufferInfo.layers = 1;

        if (vkCreateFramebuffer(g_device, &framebufferInfo, NULL, &g_framebuffers[i]) != VK_SUCCESS) {
            LOGE("Failed to create framebuffer %u", i);
            return -1;
        }
    }
    return 0;
}

/**
 * Render thread - renders frames to the swapchain
 * Currently renders a simple test pattern (clears screen with compositor background color)
 */
static void* render_thread(void* arg) {
    (void)arg;
    LOGI("Render thread started with settings:");
    LOGI("  Force Server-Side Decorations: %s", WawonaSettings_GetForceServerSideDecorations() ? "enabled" : "disabled");
    LOGI("  Auto Retina Scaling: %s", WawonaSettings_GetAutoRetinaScalingEnabled() ? "enabled" : "disabled");
    LOGI("  Rendering Backend: %d (0=Automatic, 1=Vulkan, 2=Surface)", WawonaSettings_GetRenderingBackend());
    LOGI("  Respect Safe Area: %s", WawonaSettings_GetRespectSafeArea() ? "enabled" : "disabled");
    LOGI("  Safe Area: left=%d, top=%d, right=%d, bottom=%d", 
         g_safeAreaLeft, g_safeAreaTop, g_safeAreaRight, g_safeAreaBottom);
    LOGI("  Render macOS Pointer: %s", WawonaSettings_GetRenderMacOSPointer() ? "enabled" : "disabled");
    LOGI("  Swap Cmd as Ctrl: %s", WawonaSettings_GetSwapCmdAsCtrl() ? "enabled" : "disabled");
    LOGI("  Universal Clipboard: %s", WawonaSettings_GetUniversalClipboardEnabled() ? "enabled" : "disabled");
    LOGI("  ColorSync Support: %s", WawonaSettings_GetColorSyncSupportEnabled() ? "enabled" : "disabled");
    LOGI("  Nested Compositors Support: %s", WawonaSettings_GetNestedCompositorsSupportEnabled() ? "enabled" : "disabled");
    LOGI("  Use Metal 4 for Nested: %s", WawonaSettings_GetUseMetal4ForNested() ? "enabled" : "disabled");
    LOGI("  Multiple Clients: %s", WawonaSettings_GetMultipleClientsEnabled() ? "enabled" : "disabled");
    LOGI("  Waypipe RS Support: %s", WawonaSettings_GetWaypipeRSSupportEnabled() ? "enabled" : "disabled");
    LOGI("  Enable TCP Listener: %s", WawonaSettings_GetEnableTCPListener() ? "enabled" : "disabled");
    LOGI("  TCP Port: %d", WawonaSettings_GetTCPListenerPort());
    
    // Get swapchain images
    uint32_t imageCount = 0;
    VkResult res = vkGetSwapchainImagesKHR(g_device, g_swapchain, &imageCount, NULL);
    if (res != VK_SUCCESS || imageCount == 0) {
        LOGE("Failed to get swapchain images: %d, count=%u", res, imageCount);
        return NULL;
    }
    
    VkImage* images = malloc(imageCount * sizeof(VkImage));
    res = vkGetSwapchainImagesKHR(g_device, g_swapchain, &imageCount, images);
    if (res != VK_SUCCESS) {
        LOGE("Failed to get swapchain images: %d", res);
        free(images);
        return NULL;
    }
    
    LOGI("Got %u swapchain images", imageCount);

    // Get surface capabilities for extent
    VkSurfaceCapabilitiesKHR caps;
    VkPhysicalDevice pd = pick_device();
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pd, g_surface, &caps);
    VkExtent2D extent = caps.currentExtent;

    // Create Render Pass and Framebuffers
    if (create_image_views(imageCount, images) != 0) return NULL;
    if (create_render_pass() != 0) return NULL;
    if (create_framebuffers(imageCount, extent) != 0) return NULL;
    
    // Create command pool
    VkCommandPool cmdPool;
    VkCommandPoolCreateInfo cpci = { .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO };
    cpci.queueFamilyIndex = g_queue_family; 
    cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    res = vkCreateCommandPool(g_device, &cpci, NULL, &cmdPool);
    if (res != VK_SUCCESS) {
        LOGE("Failed to create command pool: %d", res);
        free(images);
        return NULL;
    }
    
    // Create command buffer
    VkCommandBuffer cmdBuf;
    VkCommandBufferAllocateInfo cbai = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO };
    cbai.commandPool = cmdPool; 
    cbai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; 
    cbai.commandBufferCount = 1;
    res = vkAllocateCommandBuffers(g_device, &cbai, &cmdBuf);
    if (res != VK_SUCCESS) {
        LOGE("Failed to allocate command buffer: %d", res);
        vkDestroyCommandPool(g_device, cmdPool, NULL);
        free(images);
        return NULL;
    }
    
    // Render loop
    int frame_count = 0;
    while (g_running) {
        uint32_t imageIndex;
        res = vkAcquireNextImageKHR(g_device, g_swapchain, UINT64_MAX, VK_NULL_HANDLE, VK_NULL_HANDLE, &imageIndex);
        if (res != VK_SUCCESS && res != VK_SUBOPTIMAL_KHR) {
            LOGE("vkAcquireNextImageKHR failed: %d", res);
            break;
        }
        
        // Record command buffer
        VkCommandBufferBeginInfo bi = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
        bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        res = vkBeginCommandBuffer(cmdBuf, &bi);
        if (res != VK_SUCCESS) {
            LOGE("vkBeginCommandBuffer failed: %d", res);
            break;
        }
        
        // Begin Render Pass
        // LoadOp CLEAR sets the whole framebuffer to Black (Background/Margins)
        VkClearValue clearValue = {{{ 0.0f, 0.0f, 0.0f, 1.0f }}}; 
        
        VkRenderPassBeginInfo rpbi = { .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO };
        rpbi.renderPass = g_renderPass;
        rpbi.framebuffer = g_framebuffers[imageIndex];
        rpbi.renderArea.offset.x = 0;
        rpbi.renderArea.offset.y = 0;
        rpbi.renderArea.extent = extent;
        rpbi.clearValueCount = 1;
        rpbi.pClearValues = &clearValue;
        
        vkCmdBeginRenderPass(cmdBuf, &rpbi, VK_SUBPASS_CONTENTS_INLINE);

        // Capture safe area state safely
        int safeLeft = 0, safeTop = 0, safeRight = 0, safeBottom = 0;
        int respectSafeArea = 0;
        
        pthread_mutex_lock(&g_lock);
        respectSafeArea = WawonaSettings_GetRespectSafeArea();
        if (respectSafeArea) {
            safeLeft = g_safeAreaLeft;
            safeTop = g_safeAreaTop;
            safeRight = g_safeAreaRight;
            safeBottom = g_safeAreaBottom;
        }
        pthread_mutex_unlock(&g_lock);

        // If safe area enabled, clear the content area to Dark Blue
        // This leaves the margins as Black (from Render Pass LoadOp)
        if (respectSafeArea && (safeLeft > 0 || safeTop > 0 || safeRight > 0 || safeBottom > 0)) {
            // Calculate safe area rect with additional 25px padding on top/bottom
            VkRect2D safeRect;
            safeRect.offset.x = safeLeft;
            safeRect.offset.y = safeTop + 25;
            safeRect.extent.width = extent.width - safeLeft - safeRight;
            safeRect.extent.height = extent.height - safeTop - safeBottom - 50;
            
            // Log safe area for debugging (once per second)
            if (frame_count % 60 == 0) {
                LOGI("Safe Area Active - Viewport: x=%d, y=%d, w=%u, h=%u", 
                     safeRect.offset.x, safeRect.offset.y, safeRect.extent.width, safeRect.extent.height);
            }
            
            // Content clearing temporarily disabled (User Request)
            /*
            // Clear Safe Area to Dark Blue (Content)
            VkClearAttachment attachment = {0};
            attachment.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            attachment.colorAttachment = 0;
            attachment.clearValue.color.float32[0] = 24.0f/255.0f; // Dark Blue
            attachment.clearValue.color.float32[1] = 24.0f/255.0f;
            attachment.clearValue.color.float32[2] = 49.0f/255.0f;
            attachment.clearValue.color.float32[3] = 1.0f;
            
            VkClearRect rect = {0};
            rect.rect = safeRect;
            rect.baseArrayLayer = 0;
            rect.layerCount = 1;
            
            vkCmdClearAttachments(cmdBuf, 1, &attachment, 1, &rect);
            */
        } else {
            // Content clearing temporarily disabled (User Request)
            /*
            // Full Screen Content (Dark Blue)
            VkClearAttachment attachment = {0};
            attachment.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            attachment.colorAttachment = 0;
            attachment.clearValue.color.float32[0] = 24.0f/255.0f; // Dark Blue
            attachment.clearValue.color.float32[1] = 24.0f/255.0f;
            attachment.clearValue.color.float32[2] = 49.0f/255.0f;
            attachment.clearValue.color.float32[3] = 1.0f;
            
            VkClearRect rect = {0};
            rect.rect.offset.x = 0;
            rect.rect.offset.y = 0;
            rect.rect.extent = extent;
            rect.baseArrayLayer = 0;
            rect.layerCount = 1;
            
            vkCmdClearAttachments(cmdBuf, 1, &attachment, 1, &rect);
            */
        }

        vkCmdEndRenderPass(cmdBuf);
        
        res = vkEndCommandBuffer(cmdBuf);
        if (res != VK_SUCCESS) {
            LOGE("vkEndCommandBuffer failed: %d", res);
            break;
        }
        
        // Submit command buffer
        VkSubmitInfo submit = { .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO };
        submit.commandBufferCount = 1;
        submit.pCommandBuffers = &cmdBuf;
        
        VkFence fence;
        VkFenceCreateInfo fci = { .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO };
        vkCreateFence(g_device, &fci, NULL, &fence);
        
        res = vkQueueSubmit(g_queue, 1, &submit, fence);
        if (res != VK_SUCCESS) {
            LOGE("vkQueueSubmit failed: %d", res);
            vkDestroyFence(g_device, fence, NULL);
            break;
        }
        
        vkWaitForFences(g_device, 1, &fence, VK_TRUE, UINT64_MAX);
        vkDestroyFence(g_device, fence, NULL);
        
        // Present
        VkPresentInfoKHR present = { .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR };
        present.swapchainCount = 1;
        present.pSwapchains = &g_swapchain;
        present.pImageIndices = &imageIndex;
        
        res = vkQueuePresentKHR(g_queue, &present);
        if (res != VK_SUCCESS && res != VK_SUBOPTIMAL_KHR) {
            LOGE("vkQueuePresentKHR failed: %d", res);
            break;
        }
        
        frame_count++;
        if (frame_count % 60 == 0) LOGI("Rendered frame %d", frame_count);
        usleep(166666); // ~60 FPS
    }
    
    vkDeviceWaitIdle(g_device);
    vkFreeCommandBuffers(g_device, cmdPool, 1, &cmdBuf);
    vkDestroyCommandPool(g_device, cmdPool, NULL);
    free(images);
    
    LOGI("Render thread stopped, rendered %d frames", frame_count);
    return NULL;
}

// ============================================================================
// JNI Interface
// ============================================================================

/**
 * Initialize the compositor - create Vulkan instance
 * Called from Android Activity.onCreate()
 */
JNIEXPORT void JNICALL
Java_com_aspauldingcode_wawona_WawonaNative_nativeInit(JNIEnv* env, jobject thiz) {
    (void)env; (void)thiz;
    pthread_mutex_lock(&g_lock);
    if (g_instance != VK_NULL_HANDLE) {
        pthread_mutex_unlock(&g_lock);
        return;
    }
    LOGI("Starting Wawona Compositor (Android) - iOS Settings Mode with Safe Area");
    VkResult r = create_instance();
    if (r != VK_SUCCESS) {
        pthread_mutex_unlock(&g_lock);
        return;
    }
    uint32_t count = 0; 
    VkResult res = vkEnumeratePhysicalDevices(g_instance, &count, NULL);
    LOGI("vkEnumeratePhysicalDevices count=%u, res=%d", count, res);
    pthread_mutex_unlock(&g_lock);
}

/**
 * Set the Android Surface and initialize rendering
 * Called when the SurfaceView is created/updated
 */
JNIEXPORT void JNICALL
Java_com_aspauldingcode_wawona_WawonaNative_nativeSetSurface(JNIEnv* env, jobject thiz, jobject surface) {
    (void)thiz;
    pthread_mutex_lock(&g_lock);
    
    LOGI("nativeSetSurface called");

    if (g_window) {
        LOGI("Releasing existing ANativeWindow");
        ANativeWindow_release(g_window);
        g_window = NULL;
    }

    ANativeWindow* win = ANativeWindow_fromSurface(env, surface);
    if (!win) { 
        LOGE("ANativeWindow_fromSurface returned NULL"); 
        pthread_mutex_unlock(&g_lock);
        return; 
    }
    g_window = win;
    LOGI("Received ANativeWindow %p", (void*)win);
    
    // Skip safe area update for now - thiz is WawonaNative object, not Activity
    // Safe area will be updated when settings are applied via nativeApplySettings
    LOGI("Skipping safe area update (will be set via settings)");
    g_safeAreaLeft = 0;
    g_safeAreaTop = 0;
    g_safeAreaRight = 0;
    g_safeAreaBottom = 0;
    
    if (g_instance == VK_NULL_HANDLE) {
        LOGI("Creating Vulkan instance...");
        if (create_instance() != VK_SUCCESS) {
            LOGE("Failed to create Vulkan instance");
            ANativeWindow_release(win);
            g_window = NULL;
            pthread_mutex_unlock(&g_lock);
            return;
        }
        LOGI("Vulkan instance created");
    } else {
        LOGI("Vulkan instance already exists");
    }
    
    LOGI("Creating Android surface...");
    VkAndroidSurfaceCreateInfoKHR sci = { .sType = VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR };
    sci.window = win;
    VkResult res = vkCreateAndroidSurfaceKHR(g_instance, &sci, NULL, &g_surface);
    if (res != VK_SUCCESS) { 
        LOGE("vkCreateAndroidSurfaceKHR failed: %d", res); 
        ANativeWindow_release(win);
        g_window = NULL;
        pthread_mutex_unlock(&g_lock);
        return; 
    }
    LOGI("Android VkSurfaceKHR created: %p", (void*)g_surface);
    
    LOGI("Picking Vulkan device...");
    VkPhysicalDevice pd = pick_device();
    if (pd == VK_NULL_HANDLE) {
        LOGE("No Vulkan devices found");
        vkDestroySurfaceKHR(g_instance, g_surface, NULL);
        ANativeWindow_release(win);
        g_window = NULL;
        pthread_mutex_unlock(&g_lock);
        return;
    }
    LOGI("Vulkan device picked");
    
    LOGI("Creating Vulkan device...");
    if (create_device(pd) != 0) {
        LOGE("Failed to create device");
        vkDestroySurfaceKHR(g_instance, g_surface, NULL);
        ANativeWindow_release(win);
        g_window = NULL;
        pthread_mutex_unlock(&g_lock);
        return;
    }
    LOGI("Vulkan device created");
    
    LOGI("Creating swapchain...");
    if (create_swapchain(pd) != 0) {
        LOGE("Failed to create swapchain");
        vkDestroyDevice(g_device, NULL);
        vkDestroySurfaceKHR(g_instance, g_surface, NULL);
        ANativeWindow_release(win);
        g_window = NULL;
        pthread_mutex_unlock(&g_lock);
        return;
    }
    LOGI("Swapchain created");
    
    // Start render thread with delay to ensure surface is ready
    LOGI("Starting render thread...");
    g_running = 1; 
    usleep(500000); // 500ms delay to let surface stabilize
    int thread_result = pthread_create(&g_render_thread, NULL, render_thread, NULL);
    if (thread_result != 0) {
        LOGE("Failed to create render thread: %d", thread_result);
        g_running = 0;
        vkDestroySwapchainKHR(g_device, g_swapchain, NULL);
        vkDestroyDevice(g_device, NULL);
        vkDestroySurfaceKHR(g_instance, g_surface, NULL);
        ANativeWindow_release(win);
        g_window = NULL;
        pthread_mutex_unlock(&g_lock);
        return;
    }
    LOGI("Render thread created successfully");
    
    LOGI("Wawona Compositor initialized successfully");
    pthread_mutex_unlock(&g_lock);
}

/**
 * Destroy surface and clean up Vulkan resources
 * Called when the SurfaceView is destroyed
 */
JNIEXPORT void JNICALL
Java_com_aspauldingcode_wawona_WawonaNative_nativeDestroySurface(JNIEnv* env, jobject thiz) {
    (void)env; (void)thiz;
    pthread_mutex_lock(&g_lock);
    
    LOGI("Destroying surface");
    g_running = 0;
    
    // Wait for render thread to finish
    if (g_render_thread) {
        pthread_join(g_render_thread, NULL);
        g_render_thread = 0;
    }
    
    // Clean up Vulkan resources
    if (g_device != VK_NULL_HANDLE) {
        vkDeviceWaitIdle(g_device);
    }
    
    // Clean up Framebuffers
    if (g_framebuffers) {
        for (uint32_t i = 0; i < g_swapchainImageCount; i++) {
            vkDestroyFramebuffer(g_device, g_framebuffers[i], NULL);
        }
        free(g_framebuffers);
        g_framebuffers = NULL;
    }

    // Clean up Render Pass
    if (g_renderPass != VK_NULL_HANDLE) {
        vkDestroyRenderPass(g_device, g_renderPass, NULL);
        g_renderPass = VK_NULL_HANDLE;
    }

    // Clean up Image Views
    if (g_imageViews) {
        for (uint32_t i = 0; i < g_swapchainImageCount; i++) {
            vkDestroyImageView(g_device, g_imageViews[i], NULL);
        }
        free(g_imageViews);
        g_imageViews = NULL;
    }
    
    if (g_swapchain && g_device) {
        vkDestroySwapchainKHR(g_device, g_swapchain, NULL);
        g_swapchain = VK_NULL_HANDLE;
    }
    
    if (g_surface && g_instance) {
        vkDestroySurfaceKHR(g_instance, g_surface, NULL);
        g_surface = VK_NULL_HANDLE;
    }
    
    if (g_device) {
        vkDestroyDevice(g_device, NULL);
        g_device = VK_NULL_HANDLE;
    }
    
    if (g_instance) {
        vkDestroyInstance(g_instance, NULL);
        g_instance = VK_NULL_HANDLE;
    }

    if (g_window) {
        ANativeWindow_release(g_window);
        g_window = NULL;
    }
    
    LOGI("Surface destroyed");
    pthread_mutex_unlock(&g_lock);
}

/**
 * Update safe area insets from Android WindowInsets API
 * Called directly from Kotlin to avoid complex JNI reflection
 */
JNIEXPORT void JNICALL Java_com_aspauldingcode_wawona_WawonaNative_nativeUpdateSafeArea(JNIEnv* env, jobject thiz, jint left, jint top, jint right, jint bottom) {
    (void)env;
    (void)thiz;
    pthread_mutex_lock(&g_lock);
    
    g_rawSafeAreaLeft = left;
    g_rawSafeAreaTop = top;
    g_rawSafeAreaRight = right;
    g_rawSafeAreaBottom = bottom;
    
    if (WawonaSettings_GetRespectSafeArea()) {
        g_safeAreaLeft = left;
        g_safeAreaTop = top;
        g_safeAreaRight = right;
        g_safeAreaBottom = bottom;
        LOGI("JNI Update Safe Area: Applied (L=%d, T=%d, R=%d, B=%d)", left, top, right, bottom);
    } else {
        g_safeAreaLeft = 0;
        g_safeAreaTop = 0;
        g_safeAreaRight = 0;
        g_safeAreaBottom = 0;
        LOGI("JNI Update Safe Area: Cached (L=%d, T=%d, R=%d, B=%d), but disabled", left, top, right, bottom);
    }
    
    pthread_mutex_unlock(&g_lock);
}

/**
 * Apply iOS-compatible settings
 * Provides 1:1 mapping of iOS settings for cross-platform compatibility
 */
JNIEXPORT void JNICALL
Java_com_aspauldingcode_wawona_WawonaNative_nativeApplySettings(JNIEnv* env, jobject thiz,
                                                                jboolean forceServerSideDecorations,
                                                                jboolean autoRetinaScaling,
                                                                jint renderingBackend,
                                                                jboolean respectSafeArea,
                                                                jboolean renderMacOSPointer,
                                                                jboolean swapCmdAsCtrl,
                                                                jboolean universalClipboard,
                                                                jboolean colorSyncSupport,
                                                                jboolean nestedCompositorsSupport,
                                                                jboolean useMetal4ForNested,
                                                                jboolean multipleClients,
                                                                jboolean waypipeRSSupport,
                                                                jboolean enableTCPListener,
                                                                jint tcpPort) {
    (void)thiz;
    pthread_mutex_lock(&g_lock);
    
    LOGI("Applying Wawona settings:");
    LOGI("  Force Server-Side Decorations: %s", forceServerSideDecorations ? "enabled" : "disabled");
    LOGI("  Auto Retina Scaling: %s", autoRetinaScaling ? "enabled" : "disabled");
    LOGI("  Rendering Backend: %d (0=Automatic, 1=Vulkan, 2=Surface)", renderingBackend);
    LOGI("  Respect Safe Area: %s", respectSafeArea ? "enabled" : "disabled");
    LOGI("  Render Software Pointer: %s", renderMacOSPointer ? "enabled" : "disabled");
    LOGI("  Swap Cmd as Ctrl: %s", swapCmdAsCtrl ? "enabled" : "disabled");
    LOGI("  Universal Clipboard: %s", universalClipboard ? "enabled" : "disabled");
    LOGI("  ColorSync Support: %s", colorSyncSupport ? "enabled" : "disabled");
    LOGI("  Nested Compositors Support: %s", nestedCompositorsSupport ? "enabled" : "disabled");
    LOGI("  Use Metal 4 for Nested: %s", useMetal4ForNested ? "enabled" : "disabled");
    LOGI("  Multiple Clients: %s", multipleClients ? "enabled" : "disabled");
    LOGI("  Waypipe RS Support: %s", waypipeRSSupport ? "enabled" : "disabled");
    LOGI("  Enable TCP Listener: %s", enableTCPListener ? "enabled" : "disabled");
    LOGI("  TCP Port: %d", tcpPort);
    
    // Apply settings
    WawonaSettingsConfig config = {
        .forceServerSideDecorations = forceServerSideDecorations,
        .autoRetinaScaling = autoRetinaScaling,
        .renderingBackend = renderingBackend,
        .respectSafeArea = respectSafeArea,
        .renderMacOSPointer = renderMacOSPointer,
        .swapCmdAsCtrl = swapCmdAsCtrl,
        .universalClipboard = universalClipboard,
        .colorSyncSupport = colorSyncSupport,
        .nestedCompositorsSupport = nestedCompositorsSupport,
        .useMetal4ForNested = useMetal4ForNested,
        .multipleClients = multipleClients,
        .waypipeRSSupport = waypipeRSSupport,
        .enableTCPListener = enableTCPListener,
        .tcpPort = tcpPort,
        .vulkanDrivers = false,
        .eglDrivers = false
    };
    WawonaSettings_UpdateConfig(&config);
    
    // Update safe area based on new setting
    if (respectSafeArea) {
        g_safeAreaLeft = g_rawSafeAreaLeft;
        g_safeAreaTop = g_rawSafeAreaTop;
        g_safeAreaRight = g_rawSafeAreaRight;
        g_safeAreaBottom = g_rawSafeAreaBottom;
    } else {
        g_safeAreaLeft = 0;
        g_safeAreaTop = 0;
        g_safeAreaRight = 0;
        g_safeAreaBottom = 0;
    }
    
    LOGI("Safe area updated based on settings: %s (L=%d, T=%d, R=%d, B=%d)", 
         respectSafeArea ? "enabled" : "disabled",
         g_safeAreaLeft, g_safeAreaTop, g_safeAreaRight, g_safeAreaBottom);
    
    LOGI("Wawona settings applied successfully with safe area support");
    pthread_mutex_unlock(&g_lock);
}

// ============================================================================
// JNI Initialization
// ============================================================================

static int pfd[2];
static pthread_t thr;
static const char *tag = "Wawona-Stdout";

static void *thread_func(void *arg)
{
    ssize_t rdsz;
    char buf[128];
    while((rdsz = read(pfd[0], buf, sizeof buf - 1)) > 0) {
        if(buf[rdsz - 1] == '\n') --rdsz;
        buf[rdsz] = 0;  /* add null-terminator */
        __android_log_write(ANDROID_LOG_DEBUG, tag, buf);
    }
    return 0;
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    // Redirect stdout/stderr to logcat
    setvbuf(stdout, 0, _IOLBF, 0);
    setvbuf(stderr, 0, _IONBF, 0);
    pipe(pfd);
    dup2(pfd[1], 1);
    dup2(pfd[1], 2);
    if(pthread_create(&thr, 0, thread_func, 0) == -1)
        return -1;
    pthread_detach(thr);
    
    return JNI_VERSION_1_6;
}


