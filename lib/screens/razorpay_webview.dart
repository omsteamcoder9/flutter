// // lib/screens/razorpay_webview.dart
// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import '../services/api_service.dart';

// class RazorpayWebView extends StatefulWidget {
//   final String orderId;
//   final double amount;
//   final String name;
//   final String email;
//   final String phone;

//   const RazorpayWebView({
//     super.key,
//     required this.orderId,
//     required this.amount,
//     required this.name,
//     required this.email,
//     required this.phone,
//   });

//   @override
//   State<RazorpayWebView> createState() => _RazorpayWebViewState();
// }

// class _RazorpayWebViewState extends State<RazorpayWebView> {
//   late final WebViewController _controller;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _initWebView();
//   }

//   void _initWebView() {
//     final String htmlContent = '''
//       <!DOCTYPE html>
//       <html>
//       <head>
//         <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
//         <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
//         <style>
//           body {
//             margin: 0;
//             padding: 0;
//             font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
//           }
//           .loader-container {
//             display: flex;
//             justify-content: center;
//             align-items: center;
//             height: 100vh;
//             flex-direction: column;
//           }
//           .spinner {
//             width: 40px;
//             height: 40px;
//             border: 4px solid #f3f3f3;
//             border-top: 4px solid #D53E0F;
//             border-radius: 50%;
//             animation: spin 1s linear infinite;
//             margin-bottom: 20px;
//           }
//           @keyframes spin {
//             0% { transform: rotate(0deg); }
//             100% { transform: rotate(360deg); }
//           }
//           .loader-text {
//             color: #666;
//             font-size: 14px;
//           }
//           .debug-log {
//             position: fixed;
//             bottom: 0;
//             left: 0;
//             right: 0;
//             background: rgba(0,0,0,0.8);
//             color: #0f0;
//             font-size: 10px;
//             padding: 5px;
//             max-height: 100px;
//             overflow-y: auto;
//             z-index: 9999;
//             font-family: monospace;
//           }
//         </style>
//       </head>
//       <body>
//         <div class="loader-container" id="loader">
//           <div class="spinner"></div>
//           <div class="loader-text">Loading payment gateway...</div>
//         </div>
//         <div class="debug-log" id="debugLog"></div>
        
//         <script>
//           function addDebugLog(message) {
//             console.log(message);
//             const logDiv = document.getElementById('debugLog');
//             if (logDiv) {
//               const p = document.createElement('div');
//               p.textContent = new Date().toLocaleTimeString() + ': ' + message;
//               logDiv.appendChild(p);
//               logDiv.scrollTop = logDiv.scrollHeight;
//             }
//           }
          
//           addDebugLog('🚀 Page loaded');
//           addDebugLog('📦 Order ID: ${widget.orderId}');
//           addDebugLog('💰 Amount: ${widget.amount}');
//           addDebugLog('💰 Amount in paise: ${(widget.amount * 100).toString()}');
//           addDebugLog('👤 Name: ${widget.name}');
//           addDebugLog('📧 Email: ${widget.email}');
//           addDebugLog('📱 Phone: ${widget.phone}');
//           addDebugLog('🌐 API URL: ${ApiService.baseUrl}');
          
//           async function initiatePayment() {
//             addDebugLog('1️⃣ Step 1: Creating Razorpay order...');
//             addDebugLog('   Order ID: ${widget.orderId}');
            
//             try {
//               const url = '${ApiService.baseUrl}/payments/create-order';
//               addDebugLog('   Fetch URL: ' + url);
              
//               const response = await fetch(url, {
//                 method: 'POST',
//                 headers: {
//                   'Content-Type': 'application/json',
//                 },
//                 body: JSON.stringify({
//                   orderId: '${widget.orderId}'
//                 })
//               });
              
//               addDebugLog('   Response status: ' + response.status);
              
//               const data = await response.json();
//               addDebugLog('2️⃣ Create Order Response: ' + JSON.stringify(data));
              
//               if (data.success) {
//                 addDebugLog('3️⃣ Order created successfully');
//                 addDebugLog('   Razorpay Key: ' + data.key);
//                 addDebugLog('   Razorpay Order ID: ' + data.order.id);
//                 addDebugLog('   Amount: ' + data.order.amount);
//                 addDebugLog('   Currency: ' + data.order.currency);
                
//                 var options = {
//                   key: data.key,
//                   amount: ${(widget.amount * 100).toString()},
//                   currency: 'INR',
//                   name: 'MeenavanFresh',
//                   description: 'Order ${widget.orderId}',
//                   order_id: data.order.id,
//                   prefill: {
//                     name: '${widget.name.replaceAll("'", "\\'")}',
//                     email: '${widget.email}',
//                     contact: '${widget.phone}'
//                   },
//                   theme: {
//                     color: '#D53E0F'
//                   },
//                   handler: function(response) {
//                     addDebugLog('4️⃣ Payment Success Response: ' + JSON.stringify(response));
//                     addDebugLog('   Payment ID: ' + response.razorpay_payment_id);
//                     addDebugLog('   Order ID: ' + response.razorpay_order_id);
//                     addDebugLog('   Signature: ' + response.razorpay_signature);
                    
//                     fetch('${ApiService.baseUrl}/payments/verify-payment', {
//                       method: 'POST',
//                       headers: {
//                         'Content-Type': 'application/json',
//                       },
//                       body: JSON.stringify({
//                         razorpay_order_id: response.razorpay_order_id,
//                         razorpay_payment_id: response.razorpay_payment_id,
//                         razorpay_signature: response.razorpay_signature
//                       })
//                     })
//                     .then(res => res.json())
//                     .then(result => {
//                       addDebugLog('5️⃣ Verification Response: ' + JSON.stringify(result));
//                       if (result.success) {
//                         addDebugLog('✅ Payment verified! Order confirmed.');
//                         window.RazorpayWebView.postMessage('success:' + result.order.orderId);
//                       } else {
//                         addDebugLog('❌ Verification failed: ' + result.message);
//                         window.RazorpayWebView.postMessage('error:' + (result.message || 'Payment verification failed'));
//                       }
//                     })
//                     .catch(err => {
//                       addDebugLog('❌ Verification error: ' + err.message);
//                       window.RazorpayWebView.postMessage('error:' + err.message);
//                     });
//                   },
//                   modal: {
//                     ondismiss: function() {
//                       addDebugLog('❌ Payment modal dismissed by user');
//                       window.RazorpayWebView.postMessage('cancelled');
//                     }
//                   }
//                 };
                
//                 addDebugLog('6️⃣ Opening Razorpay checkout...');
//                 addDebugLog('   Options: ' + JSON.stringify(options));
//                 var rzp = new Razorpay(options);
//                 rzp.on('payment.failed', function(response) {
//                   addDebugLog('❌ Payment failed: ' + JSON.stringify(response));
//                   window.RazorpayWebView.postMessage('error:' + (response.error?.description || 'Payment failed'));
//                 });
//                 rzp.open();
//               } else {
//                 addDebugLog('❌ Create order failed: ' + data.message);
//                 window.RazorpayWebView.postMessage('error:' + (data.message || 'Failed to create order'));
//               }
//             } catch (error) {
//               addDebugLog('❌ Exception in initiatePayment: ' + error.message);
//               addDebugLog('   Stack: ' + error.stack);
//               window.RazorpayWebView.postMessage('error:' + error.message);
//             }
//           }
          
//           // Start payment after a short delay
//           setTimeout(initiatePayment, 1000);
//         </script>
//       </body>
//       </html>
//     ''';
    
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..addJavaScriptChannel(
//         'RazorpayWebView',
//         onMessageReceived: (JavaScriptMessage message) {
//           final String msg = message.message;
//           print('🔔 RazorpayWebView message: $msg');
//           if (msg.startsWith('success:')) {
//             final orderId = msg.substring(8);
//             print('✅ Payment success! Order ID: $orderId');
//             Navigator.pop(context, {'success': true, 'orderId': orderId});
//           } else if (msg == 'cancelled') {
//             print('❌ Payment cancelled by user');
//             Navigator.pop(context, {'success': false, 'message': 'Payment cancelled'});
//           } else if (msg.startsWith('error:')) {
//             final errorMsg = msg.substring(6);
//             print('❌ Payment error: $errorMsg');
//             Navigator.pop(context, {'success': false, 'message': errorMsg});
//           }
//         },
//       )
//       ..loadHtmlString(htmlContent);
    
//     setState(() {
//       _isLoading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Secure Payment'),
//         backgroundColor: const Color(0xFF5E0006),
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: _isLoading
//           ? const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD53E0F)),
//                   ),
//                   SizedBox(height: 16),
//                   Text('Loading...'),
//                 ],
//               ),
//             )
//           : WebViewWidget(controller: _controller),
//     );
//   }
// }