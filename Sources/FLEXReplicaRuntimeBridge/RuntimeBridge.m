#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "FLEXReplicaRuntimeBridge.h"

NSArray<NSString *> *FLEXReplicaCopyRuntimeClassNames(void) {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (classes == NULL) {
        return @[];
    }

    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int index = 0; index < count; index++) {
        const char *rawName = class_getName(classes[index]);
        if (rawName == NULL) {
            continue;
        }
        NSString *name = [NSString stringWithUTF8String:rawName];
        if (name != nil) {
            [names addObject:name];
        }
    }
    free(classes);
    [names sortUsingSelector:@selector(compare:)];
    return [names copy];
}

BOOL FLEXReplicaTryGetObjectValue(id object, NSString *key, id __autoreleasing *valueOut) {
    if (object == nil || key.length == 0 || valueOut == NULL) {
        return NO;
    }
    *valueOut = nil;
    @try {
        *valueOut = [object valueForKey:key];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

BOOL FLEXReplicaTrySetObjectValue(id object, NSString *key, id value) {
    if (object == nil || key.length == 0) {
        return NO;
    }
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}
