# virtual_queue

A Flutter-based mobile application for restaurant queue management and reservations, using Firebase Authentication and Cloud Firestore.

# Installation and Setup
# Step 1: Install the Prerequisites
Install the following tools before running the application:

Flutter SDK – required to build and run the application.
Android Studio – provides the Android SDK and emulator.
Git – required to download the project from GitHub.

# Step 2: Clone the Repository
Open Terminal and run:

git clone https://github.com/ngjingwen-0320/virtual_queue.git
cd virtual_queue

This downloads the project source code from GitHub and opens the project directory.

# Step 3: Install Dependencies
Run the following command from the project root directory:

flutter pub get

This downloads the Flutter packages required by the application.

# Step 4: Configure Firebase
The application uses Firebase Authentication for login and Cloud Firestore to store application data.

Ensure that google-services.json exists in:

android/app/google-services.json

The file must belong to the Firebase project configured for Virtual Queue. The Firebase backend must also have Email/Password Authentication enabled, the required Firestore database and security rules, and the demo account data.

# Step 5: Run the Application
Start an Android emulator through Android Studio or connect an Android device with USB debugging enabled.

Check that the device is detected:

flutter devices

Then launch the application:

flutter run

Flutter will build and install the application on the selected device.

# Step 6: Build the Release APK (Optional)
To build an installable Android release APK, run:

flutter build apk --release

The generated APK can be found at:

build/app/outputs/flutter-apk/app-release.apk

Transfer the APK to an Android device to install and test the release version.

# Demo Accounts
Use the following accounts to test the application (OTP required):

Role: Customer
Email: p23015051@student.newinti.edu.my
Password: 0320ngjingwen

Role: Restaurant
Email: 320.ngjingwen@gmail.com 
Password: Madamkwan123

Enter the relevant password during login. Both accounts require OTP verification, so access to the corresponding email inbox is needed to retrieve the OTP.