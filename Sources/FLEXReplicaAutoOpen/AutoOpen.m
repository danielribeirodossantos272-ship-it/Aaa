#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import "FLEXReplicaAutoOpen.h"

extern void FLEXReplicaInstallFloatingButton(void);

static BOOL gFLEXReplicaDidInstallButton = NO;
static NSUInteger gFLEXReplicaRetries = 0;
static id gFLEXReplicaApplicationObserver = nil;
static id gFLEXReplicaSceneObserver = nil;

static void FLEXReplicaTryInstallButton(void);

static BOOL FLEXReplicaHasForegroundKeyWindow(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (application.applicationState != UIApplicationStateActive) {
        return NO;
    }

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]] ||
            scene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow && window.rootViewController != nil) {
                return YES;
            }
        }
    }
    return NO;
}

static void FLEXReplicaStopObserving(void) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (gFLEXReplicaApplicationObserver != nil) {
        [center removeObserver:gFLEXReplicaApplicationObserver];
        gFLEXReplicaApplicationObserver = nil;
    }
    if (gFLEXReplicaSceneObserver != nil) {
        [center removeObserver:gFLEXReplicaSceneObserver];
        gFLEXReplicaSceneObserver = nil;
    }
}

static void FLEXReplicaInstallObservers(void) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (gFLEXReplicaApplicationObserver == nil) {
        gFLEXReplicaApplicationObserver = [center
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *notification) {
            gFLEXReplicaRetries = 0;
            FLEXReplicaTryInstallButton();
        }];
    }
    if (gFLEXReplicaSceneObserver == nil) {
        gFLEXReplicaSceneObserver = [center
            addObserverForName:UISceneDidActivateNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *notification) {
            gFLEXReplicaRetries = 0;
            FLEXReplicaTryInstallButton();
        }];
    }
}

static void FLEXReplicaTryInstallButton(void) {
    if (gFLEXReplicaDidInstallButton) {
        return;
    }
    if (!FLEXReplicaHasForegroundKeyWindow()) {
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive &&
            gFLEXReplicaRetries < 40) {
            gFLEXReplicaRetries += 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                FLEXReplicaTryInstallButton();
            });
        }
        return;
    }

    gFLEXReplicaDidInstallButton = YES;
    FLEXReplicaStopObserving();
    FLEXReplicaInstallFloatingButton();
}

__attribute__((constructor))
static void FLEXReplicaInstallButtonWhenLoaded(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        FLEXReplicaInstallObservers();
        FLEXReplicaTryInstallButton();
    });
}

// Referenced by Swift so the linker retains this object and its constructor.
int FLEXReplicaAutoOpenEnsureLinked(void) {
    return 1;
}
