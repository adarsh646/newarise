# Razorpay Payment Integration Setup Guide

## ✅ What Has Been Implemented

1. **Razorpay Payment Integration** - Added `razorpay_flutter` dependency
2. **Two-Section Trainer Display**:
   - **Your Trainers** (Green section) - Trainers who have been paid for
   - **Available Trainers** (Blue section) - Trainers available for follow requests
3. **Payment Flow**:
   - User sends follow request to trainer
   - Trainer accepts the request
   - User sees "Pay ₹{fee}" button
   - After successful payment, trainer moves to "Your Trainers" section

## 🔧 Setup Steps

### Step 1: Update Dependencies
Run this command:
```bash
flutter pub get
```

### Step 2: Configure Razorpay API Key
Open `lib/userhome_components/trainer_section.dart` and update the Razorpay key:

**Line ~344** - Replace with your actual key:
```dart
'key': 'rzp_live_CjvU1MN26iKbXG', // Replace with your Razorpay API key
```

To get your key:
1. Go to https://dashboard.razorpay.com/
2. Navigate to Settings → API Keys
3. Copy your **Key ID** (starts with `rzp_live_`)

### Step 3: Firestore Collections Setup

Ensure you have these Firestore collections:

#### Collection: `user_payments`
Stores all payment records:
```
user_payments/
  ├── userId: "user123"
  ├── trainerId: "trainer456"
  ├── trainerName: "John Doe"
  ├── amount: 5000 (in rupees)
  ├── paymentId: "pay_xxxxx"
  ├── orderId: "order_xxxxx"
  ├── signature: "sig_xxxxx"
  ├── timestamp: Timestamp
  └── status: "completed"
```

#### Firestore Security Rules (Add to your existing rules):
```javascript
match /user_payments/{document=**} {
  allow create: if request.auth.uid != null;
  allow read: if request.auth.uid == resource.data.userId;
  allow update, delete: if request.auth.uid == resource.data.userId;
}
```

### Step 4: Android Configuration

Add this to `android/app/build.gradle`:
```gradle
dependencies {
    implementation 'com.razorpay:checkout:1.6.33'
}
```

### Step 5: iOS Configuration

Add this to `ios/Podfile`:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1'
      ]
    end
  end
end
```

## 💳 Payment Flow

```
User Selects Trainer
        ↓
User Clicks "Follow"
        ↓
Follow Request Sent (Status: pending)
        ↓
Trainer Accepts Request (Status: accepted)
        ↓
"Pay ₹{fee}" Button Appears
        ↓
User Clicks "Pay"
        ↓
Razorpay Payment Gateway Opens
        ↓
Payment Completed Successfully
        ↓
Payment Record Saved to Firestore
        ↓
Trainer Moved to "Your Trainers" Section
        ↓
✅ Verified Badge Displayed
```

## 🧪 Testing

### Test Payment Credentials:
- **Card Number**: 4111 1111 1111 1111
- **Expiry**: Any future date (e.g., 12/25)
- **CVV**: Any 3 digits

### Test Razorpay Link:
https://razorpay.me/@adarshvairamalakannan

## 📱 UI Changes

### Before Payment:
- Available Trainers listed with "Follow" button
- Shows specialization, qualification, experience, and fee

### After Follow Request Accepted:
- Button changes to "Pay ₹{amount}"
- Trainer stays in "Available Trainers" section

### After Successful Payment:
- Trainer moves to "Your Trainers" section
- Shows green border and verified badge
- Lock icon indicates verified trainer
- Cannot be removed from this section

## 🔐 Security Considerations

1. **API Key**: Keep your `rzp_live_` key safe - don't commit it to public repos
2. **Signature Verification**: Current implementation trusts Razorpay callback (production should verify signatures on backend)
3. **Amount Validation**: Amount is fetched from Firestore trainer document
4. **User Authentication**: All payments require authenticated Firebase user

## 🐛 Debugging

If payments fail, check console logs for:
- Firebase authentication errors
- Razorpay key issues
- Network connectivity problems
- Firestore write permissions

Look for debug messages like:
```
✅ Payment Successful
✅ Payment saved successfully
❌ Error saving payment: ...
```

## 📊 Monitoring Payments

1. Go to https://dashboard.razorpay.com/payments
2. View all payment transactions
3. Check payment status, amount, and customer details
4. Download payment reports

## ⚠️ Important Notes

1. The current implementation uses a test Razorpay key - replace with production key before publishing
2. Payments are stored locally in Firestore immediately after success
3. For production, implement backend verification of Razorpay signatures
4. Consider implementing refund functionality for manual disputes
5. Add payment receipt generation for users

## 🚀 Future Enhancements

- [ ] Payment receipt generation
- [ ] Refund functionality
- [ ] Subscription/recurring payments
- [ ] Invoice generation
- [ ] Payment history for users
- [ ] Admin dashboard for payment tracking
- [ ] Multiple payment methods (Google Pay, Apple Pay, etc.)

## 📞 Support

For Razorpay integration issues, refer to:
- Official Docs: https://razorpay.com/docs/
- Flutter Plugin: https://pub.dev/packages/razorpay_flutter