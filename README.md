# LuxTech – An Inclusive , Accessibility-Focused Electronics Store Flutter App
**LuxTech** is a dual-interface mobile application developed as part of our graduation project. It’s designed to make online electronics shopping more inclusive and efficient by focusing on accessibility and usability.

## The app aims to serve two groups
1. **Primary Users:** People with partial or complete visual impairment<br>
- Built-in voice assistant that allows full navigation and interaction through intuitive, easy-to-remember voice commands.
- Designed for full control without relying on visual input.<br>

2. **Secondary Users:** 
- Normally-sighted people
- 3 color-blind-friendly themes that change the entire app's color scheme to suit different types of color vision deficiency.

## ✨ App Features Highlights
🔐 Log In & sign Up | Email confirmation |  profile management (Data is synced with supabase in real time)
<br>

🛍️ Browse products by categories and search | 🛒 Add to cart , place/return 
orders | ⭐ Order Ratings | 🎨 Theme switcher (color blindness themes) <br>

🗣️ Voice assistant for full voice control

## Admin Dashboard Features
📦 Add, edit, and delete products

👥 Manage user access (block/unblock users)

📊 View and track orders

💳 View refund details (after approving returns)

🔁 Handle returns and customer issues

## 🛠️ Tech Stack
**Frontend:** Flutter (Dart)

**Backend:** Supabase (PostgreSQL, Auth, Storage, Function , Triggers,..)

**Database:** PostgreSQL with Row-Level Security (RLS)

**State Management:**
Provider is the main state management solution. The app uses ``ChangeNotifierProvider``, ``MultiProvider``, and classes like ``ProductProvider`` , ``CartProvider``, ``AuthProvider``, ``OrderProvider``, and ``WishlistProvider`` <br>All of which extend ChangeNotifier for ``reactive updates``.

**Local Storage Management:** ``shared_preferences`` is used to persist local data, including:
- Auth tokens, user info, and blocked user data (``AuthProvider``)
- Cached product data and quantities (``ProductProvider``)
- Cart items (``CartProvider``)
- Wishlist items (``WishlistProvider``)

**Each provider has dedicated methods to load/save this data using ``shared_preferences``
, Examples:**

- ``ProductProvider``: ``_saveToSharedPreferences``, - ``_loadFromSharedPreferences``

- ``CartProvider``: ``_saveCartItems``, ``_loadCartItems``

- ``WishlistProvider``: ``_saveWishlistToPrefs``, ``_loadWishlistFromPrefs``

- ``AuthProvider``: ``_saveAuthData``, ``tryAutoLogin``, etc.

**Authentication:** Supabase Auth with role-based access (Admin , User)

**Realtime Sync:** Supabase Realtime Subscriptions – to sync products,and user data without reloading manually.

**Offline Caching:** Local database caches product data on the device to reduce redundant Supabase fetches. Data updates automatically via Supabase Realtime subscriptions whenever a change is detected.

**Media Hosting:** Supabase Storage – for storing and retrieving product images.


<details>
<summary>📦 <strong>Additional Libraries & Packages Used</strong></summary>

### 🖌️ UI/UX & Utility  
- `flutter_svg` – Render SVG images  
- `cached_network_image` – Image caching with placeholders  
- `shimmer` – Skeleton loaders  
- `carousel_slider`, `dots_indicator` – For image sliders  
- `lottie` – Animated assets  
- `fl_chart` – Graphs and charts  
- `google_fonts`, `intl` – Fonts and localization  

### 🧭 Navigation  
- `go_router` – Declarative routing and deep linking  

### 📱 Device & Platform Integration  
- `connectivity_plus` – Network status  
- `local_auth` – Fingerprint/face authentication  
- `package_info_plus`, `device_info_plus` – Device/app info  
- `path_provider` – Accessing file system  

### 🌐 HTTP Requests  
- `http` – Used for Supabase functions and other HTTP calls  

## 🗃️ Backend & Database
- ``supabase_flutter`` – Supabase integration (auth, database, storage)

## 📦 Core & State Management
``provider`` – Main state management solution 

### 🚀 Splash & Icons  
- `flutter_launcher_icons` – App icon generation  
- `flutter_native_splash` – Custom splash screen  

## 🔑 Permissions & Device
- ``permission_handler`` – Runtime permissions

### 🗣️ Voice & Accessibility
- ``speech_to_text`` – Speech recognition
- ``flutter_tts`` – Text-to-speech
</details>


## Full App Screenshots:
- [🧑‍🦱 Secondary Users Interface](docs/secondary.md)

- [🛡️ Admin Dashboard Interface](docs/admin.md) 

- [🦯 Primary Users Interface](docs/primary.md)

### Full App Video:
Coming Soon.

## 🙏 Special Thanks
Our Academic Doctors and Supervisors:
Thank you for your valuable guidance, insights, and constant encouragement which helped bring this project to life.
Your support and collaboration were essential to the success of this work.

👥 My Teammates:<br>
- [Yassa Mouris](https://github.com/yassaYM7)
- [Mostafa Hassan](https://github.com/Mostafaa212)
- [Khaled Ashraf](https://github.com/Recker-13)

Thank you for your dedication, and contribution throughout the project.

## 📄 License
This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license.   [![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)


You may use, copy, and adapt this project **only for non-commercial purposes** and must give appropriate credit.

🔗 [View License Details](https://creativecommons.org/licenses/by-nc/4.0/)
