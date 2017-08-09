//
//  MPKitSingular.m
//

#import "MPKitSingular.h"
#import "Singular.h"

// This is temporary to allow compilation (will be provided by core SDK)
NSUInteger MPKitInstanceSingularTemp = 119;

@implementation MPKitSingular

#define API_KEY @"apiKey"
#define SECRET_KEY @"secret"
#define DDL_TIMEOUT @"ddlTimeout"
#define TOTAL_PRODUCT_AMOUNT @"Total Product Amount"



NSString *appKey;
NSString *secret;
int ddlTimeout = 60;

/*
 mParticle will supply a unique kit code for you. Please contact our team
 */
+ (NSNumber *)kitCode {
    return @119;
}

+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Singular" className:@"MPKitSingular" startImmediately:YES];
    [MParticle registerExtension:kitRegister];
}

#pragma mark - MPKitInstanceProtocol methods

#pragma mark Kit instance and lifecycle
- (nonnull instancetype)initWithConfiguration:(nonnull NSDictionary *)configuration startImmediately:(BOOL)startImmediately {
    self = [super init];
    
    if(configuration[API_KEY] != nil)
        appKey = configuration[API_KEY];
    if(configuration[SECRET_KEY] != nil)
        secret = configuration[SECRET_KEY];
    if(configuration[DDL_TIMEOUT] != nil){
        ddlTimeout = [configuration[DDL_TIMEOUT] intValue];
        [Singular setDeferredDeepLinkTimeout:ddlTimeout];
    }
    
    if (!self || !appKey) {
        return nil;
    }
    
    _configuration = configuration;
    
    if (startImmediately) {
        [self start];
    }
    
    return self;
}

- (void)start{
    static dispatch_once_t kitPredicate;
    dispatch_once(&kitPredicate, ^{
        /*
         Start your SDK here. The configuration dictionary can be retrieved from self.configuration
         */
        [Singular startSession:appKey withKey:secret];
        _started = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = @{mParticleKitInstanceKey:[[self class] kitCode]};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification
                                                                object:nil
                                                              userInfo:userInfo];
        });
    });
}

- (id const)providerKitInstance {
    if (![self started]) {
        return nil;
    }
    
    /*
     If your company SDK instance is available and is applicable (Please return nil if your SDK is based on class methods)
     */
    BOOL kitInstanceAvailable = NO;
    if (kitInstanceAvailable) {
        /* Return an instance of your company's SDK (if applicable) */
        return nil;
    } else {
        return nil;
    }
}


#pragma mark Application
/*
 Implement this method if your SDK retrieves deep-linking information from a remote server and returns it to the host app
 */
- (MPKitExecStatus *)checkForDeferredDeepLinkWithCompletionHandler:(void(^)(NSDictionary *linkInfo, NSError *error))completionHandler {
    [Singular registerDeferredDeepLinkHandler:^(NSString *deeplink) {
        NSDictionary *ddlLink = [[NSDictionary alloc] initWithObjectsAndKeys:deeplink,@"deepLink", nil];
        completionHandler(ddlLink,nil);
    }];
    
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceSingularTemp) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

/*
 Implement this method if your SDK registers the device token for remote notifications
 */
- (MPKitExecStatus *)setDeviceToken:(NSData *)deviceToken {
    /*  Your code goes here.
     If the execution is not successful, please use a code other than MPKitReturnCodeSuccess for the execution status.
     Please see MPKitExecStatus.h for all exec status codes
     */
    [Singular registerDeviceTokenForUninstall:deviceToken];
    
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceSingularTemp) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

#pragma mark e-Commerce
/*
 Implement this method if your SDK supports commerce events.
 If your SDK does support commerce event, but does not support all commerce event actions available in the mParticle SDK,
 expand the received commerce event into regular events and log them accordingly (see sample code below)
 Please see MPCommerceEvent.h > MPCommerceEventAction for complete list
 */
- (MPKitExecStatus *)logCommerceEvent:(MPCommerceEvent *)commerceEvent {
    
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceAppboy) returnCode:MPKitReturnCodeSuccess forwardCount:0];
    
    if (commerceEvent.action == MPCommerceEventActionPurchase){
        NSMutableDictionary *baseProductAttributes = [[NSMutableDictionary alloc] init];
        NSDictionary *transactionAttributes = [commerceEvent.transactionAttributes beautifiedDictionaryRepresentation];
        
        if (transactionAttributes) {
            [baseProductAttributes addEntriesFromDictionary:transactionAttributes];
        }
        
        NSDictionary *commerceEventAttributes = [commerceEvent beautifiedAttributes];
        NSArray *keys = @[kMPExpCECheckoutOptions, kMPExpCECheckoutStep, kMPExpCEProductListName, kMPExpCEProductListSource];
        
        for (NSString *key in keys) {
            if (commerceEventAttributes[key]) {
                baseProductAttributes[key] = commerceEventAttributes[key];
            }
        }
        
        NSArray *products = commerceEvent.products;
        NSString *currency = commerceEvent.currency ? : @"USD";
        NSMutableDictionary *properties;
        
        for (MPProduct *product in products) {
            // Add relevant attributes from the commerce event
            properties = [[NSMutableDictionary alloc] init];
            if (baseProductAttributes.count > 0) {
                [properties addEntriesFromDictionary:baseProductAttributes];
            }
            
            // Add attributes from the product itself
            NSDictionary *productDictionary = [product beautifiedDictionaryRepresentation];
            if (productDictionary) {
                [properties addEntriesFromDictionary:productDictionary];
            }
            
            // Strips key/values already being passed to Appboy, plus key/values initialized to default values
            keys = @[kMPExpProductSKU, kMPProductCurrency, kMPExpProductUnitPrice, kMPExpProductQuantity, kMPProductAffiliation, kMPExpProductCategory, kMPExpProductName];
            [properties removeObjectsForKeys:keys];
            
            //get the amount
            NSNumber *totalProductAmount = nil;
            if(properties != nil && [properties valueForKey:TOTAL_PRODUCT_AMOUNT]){
                totalProductAmount = [properties valueForKey:TOTAL_PRODUCT_AMOUNT];
            }
            
            [Singular revenue:currency amount:[totalProductAmount doubleValue] productSKU:product.sku productName:product.name productCategory:product.category productQuantity:[product.quantity intValue] productPrice:[product.price doubleValue]];
            [execStatus incrementForwardCount];
        }
        
    }else{
        NSArray *expandedInstructions = [commerceEvent expandedInstructions];
        
        for (MPCommerceEventInstruction *commerceEventInstruction in expandedInstructions) {
            [self logEvent:commerceEventInstruction.event];
            [execStatus incrementForwardCount];
        }
    }
    return execStatus;
}

#pragma mark Events
/*
 Implement this method if your SDK logs user events.
 Please see MPEvent.h
 */
- (MPKitExecStatus *)logEvent:(MPEvent *)event {
    [Singular event:event.name withArgs:event.info];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceSingularTemp) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}
@end
