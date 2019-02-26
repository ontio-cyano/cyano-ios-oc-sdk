//
//  CTWebViewController.m
//  DaiGuanJia
//
//  Created by Faney on 16/11/7.
//  Copyright © 2016年 honeywell. All rights reserved.
//  Web 控制器

#import "CTWebViewController.h"
//#import "WebViewJavascriptBridge.h"
#import "RNJsWebView.h"
#import "Helper.h"
#import "ONTECKey.h"
#import "ONTIdPreViewController.h"
#import "ONTIdExportViewController.h"
@interface CTWebViewController () <UIWebViewDelegate>

@property (strong, nonatomic) RNJsWebView *webView;
@property (strong, nonatomic) UIProgressView *progressView;

@end

@implementation CTWebViewController

- (void)dealloc
{
    NSLog(@"CTWebViewController dealloc...");
    [self.webView.wkWebView removeObserver:self forKeyPath:@"estimatedProgress"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    [self setMainNavigationBar:NavigationBarType_None goBack:GoBackType_Back];
    [self initTitleViewWithText:self.controllerTitle];
    
    [self layoutMainView];
    
    [self initHandler];
    
    if (![self.urlString containsString:@"http"])
    {
        self.urlString = [NSString stringWithFormat:@"http://%@", self.urlString];
    }
    
    NSLog(@"url:%@", self.urlString);
    [self.webView setURL:self.urlString];
//    [self.webView setURL:[NSString stringWithFormat:@"https://auth.ont.io/#/mgmtHome?ontid=%@",[GCHRAM instance].defaultONTId.ontid]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    
}

- (void)layoutMainView
{
    // Web View
    self.webView = [[RNJsWebView alloc] initWithFrame:CGRectMake(0.0f, self.navBar.frame.size.height, self.view.frame.size.width, self.view.frame.size.height - self.navBar.frame.size.height)];
    [self.view addSubview:self.webView];
    
    // Progress
    [self layoutProgressView];
}

- (void)initHandler
{
    __weak typeof(self) weakSelf = self;
    
    // Login
    [self.webView setLoginCallback:^(NSDictionary *callbackDic) {
        NSLog(@"Login:%@", [callbackDic JSONString]);
        
        ONTECKey *ecKey = [[ONTECKey alloc] initWithPriKey:[GCHApplication requestDefaultAccount].privateKey.data];
        
        NSDictionary *oriParams = callbackDic[@"params"];
        NSString * message =  oriParams[@"message"];
        NSData * messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        NSString * signMessage = [[[GCHApplication  requestDefaultAccount] signMessage:messageData] lowercaseString];
        
        NSDictionary *result =@{@"type": @"account",
                                @"publickey":[ecKey.publicKeyAsHex lowercaseString]   ,
                                @"address": [GCHApplication requestDefaultAccount].address.address,
                                @"message":message ,
                                @"signature":signMessage,
                                };
        NSDictionary *nParams = @{@"action":@"login",
                                  @"error": @0,
                                  @"desc": @"SUCCESS",
                                  @"result":result,
                                  @"id":callbackDic[@"id"],
                                  @"version":callbackDic[@"version"]
                                  };
        
        [weakSelf.webView sendMessageToWeb:nParams];
    }];
    
    // GetAccount
    [self.webView setGetAccountCallback:^(NSDictionary *callbackDic) {
        NSLog(@"GetAccount:%@", [callbackDic JSONString]);
        NSDictionary *params = @{
                                 @"action":@"getAccount",
                                 @"version":@"v1.0.0",
                                 @"error":@(0),
                                 @"desc":@"SUCCESS",
                                 @"result":[GCHRAM instance].defaultAccount.address,
                                 @"id":callbackDic[@"id"]
                                 };
        [weakSelf.webView sendMessageToWeb:params];
    }];
    
    // Invoke
    [self.webView setInvokeTransactionCallback:^(NSDictionary *callbackDic) {
        NSLog(@"Invoke:%@", [callbackDic JSONString]);
        [GCHApplication inputPassword:^{
            NSString *txHex = [weakSelf invokeHex:callbackDic];
            if (!txHex) return;
            [[ONTRpcApi shareInstance] sendRawtransactionWithHexTx:txHex preExec:NO callback:^(NSString *txHash, NSError *error) {
                if (error)
                {
                    NSLog(@"error == %@", error);
                    [CVShowLabelView showTitle:@"Invoke failed." detail:nil];
                }
                else
                {
                    NSLog(@"txHash == %@", txHash);
                    NSLog(@"View on explorer：%@", kONTScanTxURL(txHash));
                    NSDictionary *params = @{
                                             @"action":@"invoke",
                                             @"version": @"v1.0.0",
                                             @"error": @(0),
                                             @"desc": @"SUCCESS",
                                             @"result":txHash,
                                             @"id":callbackDic[@"id"]
                                             };
                    [weakSelf.webView sendMessageToWeb:params];
                }
            }];
        }];
    }];
    
    // InvokeRead
    [self.webView setInvokeReadCallback:^(NSDictionary *callbackDic) {
        NSLog(@"InvokeRead:%@", [callbackDic JSONString]);
        [GCHApplication inputPassword:^{
            ONTAccount *account = [GCHApplication requestDefaultAccount];
            [[NeoVM shareInstance].oep4 sendInit:account
                                      byGasPayer:account
                                     useGasLimit:0//10000000
                                     useGasPrice:0//500
                                         preExec:YES
                                   queryCallback:^(id result, NSError *error) {
                                       if (error) {
                                           NSLog(@"error == %@", error);
                                           [CVShowLabelView showTitle:@"Invoke read failed." detail:nil];
                                       } else {
                                           NSLog(@"result == %@", result);
                                           NSDictionary *params = @{
                                                                    @"action":@"invokeRead",
                                                                    @"version": @"v1.0.0",
                                                                    @"error": @(0),
                                                                    @"desc": @"SUCCESS",
                                                                    @"result":result,
                                                                    @"id":callbackDic[@"id"]
                                                                    };
                                           [weakSelf.webView sendMessageToWeb:params];
                                       }
                                   }];
        }];
    }];
    
    // InvokePasswordFree
    [self.webView setInvokePasswordFreeCallback:^(NSDictionary *callbackDic) {
        NSLog(@"InvokePasswordFree:%@", [callbackDic JSONString]);
        [GCHApplication inputPassword:^{
            NSString *txHex = [weakSelf invokeHex:callbackDic];
            if (!txHex) return;
            [[ONTRpcApi shareInstance] sendRawtransactionWithHexTx:txHex preExec:NO callback:^(NSString *txHash, NSError *error) {
                if (error)
                {
                    NSLog(@"error == %@", error);
                    [CVShowLabelView showTitle:@"Invoke failed." detail:nil];
                }
                else
                {
                    NSLog(@"txHash == %@", txHash);
                    NSLog(@"View on explorer：%@", kONTScanTxURL(txHash));
                    NSDictionary *params = @{
                                             @"action":@"invokePasswordFree",
                                             @"version": @"v1.0.0",
                                             @"error": @(0),
                                             @"desc": @"SUCCESS",
                                             @"result":txHash,
                                             @"id":callbackDic[@"id"]
                                             };
                    [weakSelf.webView sendMessageToWeb:params];
                }
            }];
        }];
    }];
    
    // Authentication
    [self.webView setAuthenticationCallback:^(NSDictionary *callbackDic) {
        NSLog(@"Authentication:%@",callbackDic);
        NSDictionary * params = callbackDic[@"params"];
        NSString * subaction = params[@"subaction"];
        NSArray * allSubaction = @[@"getRegistryOntidTx",@"submit",@"getIdentity"];
        NSInteger index = [allSubaction indexOfObject:subaction];
        switch (index) {
            case 0:
                [weakSelf getRegistryOntidTxRequest:callbackDic];
                break;
            case 1:
                [weakSelf submitRequest:callbackDic];
                break;
            case 2:
                [weakSelf getIdentityRequest:callbackDic];
                break;
            default:
                break;
        }
    }];
    
    // Authorization
    [self.webView setAuthorizationCallback:^(NSDictionary *callbackDic) {
        NSLog(@"callbackDic:%@",callbackDic);
        NSDictionary * params = callbackDic[@"params"];
        NSString * subaction = params[@"subaction"];
        NSArray * allSubaction = @[@"exportOntid",@"deleteOntid",@"decryptClaim",@"getAuthorizationInfo",@"requestAuthorization"];
        NSInteger index = [allSubaction indexOfObject:subaction];
        switch (index) {
            case 0:
                [weakSelf exportOntidRequest:callbackDic];
                break;
            case 1:
                [weakSelf deleteOntidRequest:callbackDic];
                break;
            case 2:
                [weakSelf decryptClaimRequest:callbackDic];
                break;
            case 3:
                [weakSelf getAuthorizationInfoRequest:callbackDic];
                break;
            case 4:
                [weakSelf requestAuthorizationRequest:callbackDic];
                break;
            default:
                break;
        }
    }];
}

// getRegistryOntidTx
-(void)getRegistryOntidTxRequest:(NSDictionary*)callbackDic{

    ONTIdentity * ONtId = [GCHApplication requestDefaultONTId];
    ONTAccount  * account = [GCHApplication requestDefaultAccount];
    ONTTransaction * RegisterOntIdTx = [ONtId makeRegisterOntIdTxWithPayer:account gasPrice:500 gasLimit:20000];
    NSString * registryOntidTx = RegisterOntIdTx.toRawByte.hexString;
    NSLog(@"%@",registryOntidTx);
    
    NSDictionary *params = @{
                             @"action":@"authentication",
                             @"version":callbackDic[@"version"],
                             @"result":
                                 @{
                                     @"subaction":@"getRegistryOntidTx",
                                     @"ontid":ONtId.ontid,
                                     @"registryOntidTx":registryOntidTx,
                                     },
                             @"id":callbackDic[@"id"],
                             @"error":@0,
                             @"desc":@"SUCCESS",
                             };
    [self.webView sendMessageToWeb:params];
}

// getIdentity
-(void)getIdentityRequest:(NSDictionary*)callbackDic{
    if ([GCHRAM instance].defaultONTId) {
        NSDictionary *params = @{
                                 @"action":@"authentication",
                                 @"version":callbackDic[@"version"],
                                 @"result":[GCHRAM instance].defaultONTId.ontid,
                                 @"id":callbackDic[@"id"],
                                 @"error":@0,
                                 @"desc":@"SUCCESS",
                                 };
        [self.webView sendMessageToWeb:params];;
    }else{
        ONTIdPreViewController * vc = [[ONTIdPreViewController alloc]init];
        [MainAppDelegate.navigationController pushViewController:vc animated:YES];
    }
}

// submit
-(void)submitRequest:(NSDictionary*)callbackDic{
    NSDictionary *params = @{
                             @"action":@"authentication",
                             @"version":callbackDic[@"version"],
                             @"result":@1,
                             @"id":callbackDic[@"id"],
                             @"error":@0,
                             @"desc":@"SUCCESS",
                             };
    [self.webView sendMessageToWeb:params];
}

// exportOntid
-(void)exportOntidRequest:(NSDictionary*)callbackDic{
    [GCHApplication inputPassword:^{
        ONTIdExportViewController * vc = [[ONTIdExportViewController alloc]init];
        vc.WIFString = [GCHRAM instance].defaultONTId.wif;
        [MainAppDelegate.navigationController pushViewController:vc animated:YES];
    }];
}

// deleteOntid
-(void)deleteOntidRequest:(NSDictionary*)callbackDic{
    [GCHApplication inputPassword:^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTONTID];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:ONTIDTX];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTACCOUTNKEYSTORE];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTIDENTITY];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [GCHApplication clearDefaultONTId];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }];
}

// decryptClaim
-(void)decryptClaimRequest:(NSDictionary*)callbackDic{
     [GCHApplication inputPassword:^{
         
     }];
}

// getAuthorizationInfo
-(void)getAuthorizationInfoRequest:(NSDictionary*)callbackDic{
    NSDictionary * resultDic = [[NSUserDefaults standardUserDefaults] valueForKey:ONTIDAUTHINFO];
    NSDictionary * resultParams = resultDic[@"params"];
    NSMutableDictionary * resultParamsChange = [NSMutableDictionary dictionaryWithDictionary:resultParams];
    resultParamsChange[@"subaction"] = @"getAuthorizationInfo";
    NSDictionary *params = @{
                             @"action":@"authorization",
                             @"version":callbackDic[@"version"],
                             @"result":resultParamsChange,
                             @"id":callbackDic[@"id"],
                             @"error":@0,
                             @"desc":@"SUCCESS",
                             };
    [self.webView sendMessageToWeb:params];
}

// requestAuthorization
-(void)requestAuthorizationRequest:(NSDictionary*)callbackDic{
    [[NSUserDefaults standardUserDefaults]setObject:callbackDic forKey:ONTIDAUTHINFO];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.webView removeFromSuperview];
    self.webView  = [[RNJsWebView alloc] initWithFrame:CGRectMake(0.0f, self.navBar.frame.size.height, self.view.frame.size.width, self.view.frame.size.height - self.navBar.frame.size.height)];
    [self.view addSubview:self.webView];
    // Progress
    [self layoutProgressView];
    

    [self.webView  setURL:@"https://auth.ont.io/#/authHome"];
    [self initHandler];
}
// Invoke
- (NSString *)invokeHex:(NSDictionary *)dic
{
    NSDictionary *invokeConfig = dic[@"params"][@"invokeConfig"];
    NSArray *functions = invokeConfig[@"functions"];
    if (functions.count <= 0)
    {
        [CVShowLabelView showTitle:@"Params error." detail:nil];
        return nil;
    }
    
    NSDictionary *function = functions[0];
    NSArray *args = function[@"args"];
    NSString *operation = function[@"operation"];
    ONTTokenType tokenType;
    NSString *toAddress;
    NSString *amount;
    if ([operation isEqualToString:@"transfer"]) {
        if (args.count != 3)
        {
            [CVShowLabelView showTitle:@"Params error." detail:nil];
            return nil;
        }
        tokenType = [invokeConfig[@"contractHash"] isEqualToString:@"0200000000000000000000000000000000000000"] ? ONTTokenTypeONG : ONTTokenTypeONT;
        toAddress = [GCHString getDictionaryValue:args[1][@"value"]];
        amount = [NSString stringWithFormat:@"%@", [GCHString getDictionaryValue:args[2][@"value"]]];
        if (tokenType == ONTTokenTypeONG) {
            amount = [Helper changeOEP4Str:amount Decimals:9];
        }
    }else{
        if (args.count != 4)
        {
            [CVShowLabelView showTitle:@"Params error." detail:nil];
            return nil;
        }
        tokenType = [(NSString *)(args[0][@"value"]) containsString:@"ong"] ? ONTTokenTypeONG : ONTTokenTypeONT;
        toAddress = [GCHString getDictionaryValue:args[2][@"value"]];
        amount = [NSString stringWithFormat:@"%@", args[3][@"value"]];
    }
    
    
    
    long gasPrice = [invokeConfig[@"gasPrice"] longValue];
    long gasLimit = [invokeConfig[@"gasLimit"] longValue];
    ONTAccount *account = [GCHApplication requestDefaultAccount];
    NSLog(@"account:%@", account);
    return [account makeTransferTxWithToken:tokenType toAddress:toAddress amount:amount gasPrice:gasPrice gasLimit:gasLimit];
}

#pragma mark - Progress

- (void)layoutProgressView
{
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, self.navBar.bottom, [[UIScreen mainScreen] bounds].size.width, 1.0f)];
    self.progressView.tintColor = MainViewsColor;
    self.progressView.transform = CGAffineTransformMakeScale(1.0f, 1.5f);
    [self.view addSubview:self.progressView];
    [self.webView.wkWebView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"estimatedProgress"])
    {
        self.progressView.progress = self.webView.wkWebView.estimatedProgress;
        if (self.progressView.progress == 1)
        {
            [UIView animateWithDuration:0.2f animations:^ {
                self.progressView.alpha = 0.0f;
            } completion:^(BOOL finished) {
                [self.progressView removeFromSuperview];
            }];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
