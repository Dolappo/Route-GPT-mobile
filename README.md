# RouteGPT

A Flutter app that provides intelligent, natural language directions using Google Maps APIs and Gemini AI.

## Enhanced Features

### 🗺️ Natural Language Directions
- **Step-by-step directions** in natural, descriptive language instead of raw street names
- **Landmark integration** - directions include nearby landmarks (e.g., "Turn right onto Adeola Odeku Street, you'll see a GTBank on your left")
- **Descriptive navigation** that helps with real-world navigation

### 📊 Route Summaries
- **Distance and duration** with real-time traffic data
- **Traffic delay calculations** showing how much longer the trip will take due to traffic
- **Travel mode clarification** (driving, walking, cycling, public transport)
- **Route summaries** for quick overviews

### 🚗 Smart Query Processing
- **Automatic travel mode detection** from user queries
- **Current location integration** - automatically uses user's location when origin is not specified
- **Query type recognition** - distinguishes between directions, duration queries, and route summaries
- **Natural language understanding** of various request formats

### 📍 Location Services
- **First-launch permission requests** for location access
- **Automatic current location detection** when origin is missing
- **Location permission management** with proper error handling
- **Cached location data** for better performance

### 🎯 User Experience
- **Plain text responses** without markdown formatting
- **Conversational tone** in all responses
- **Error handling** with helpful error messages
- **Loading states** during processing

## Example Queries

The app can now handle queries like:
- "How do I get to the mall?" (uses current location)
- "Walking directions to Central Park"
- "How long to drive from Lagos to Abuja?"
- "Bike route from home to work"
- "What's the fastest way to the airport?"

## Technical Implementation

### Enhanced Services

#### MapsService
- `getDirections()` - Enhanced with landmarks and traffic data
- `getRouteSummary()` - Quick route overviews
- `_enhanceStepsWithLandmarks()` - Adds nearby landmarks to directions
- `_getNearbyLandmarks()` - Fetches nearby points of interest
- Location permission handling and caching

#### GeminiService
- `extractLocationInfo()` - Enhanced to detect travel modes and query types
- `formatResponse()` - Natural language formatting with landmarks
- `formatRouteSummary()` - Concise route summaries
- Removes all text formatting from responses

#### ChatViewModel
- Smart query processing with travel mode detection
- Current location integration
- Enhanced error handling with user-friendly messages
- Location permission management

### Key Features
- **Real-time traffic data** integration
- **Landmark-based directions** for better navigation
- **Multi-modal transport** support (drive, walk, cycle, transit)
- **Natural language processing** for user queries
- **Location permission management** on first launch
- **Error handling** with helpful user messages

## Setup

1. Ensure you have the required API keys in your `.env` file:
   - `GOOGLE_MAPS_API_KEY`
   - `GEMINI_API_KEY`

2. The app will automatically request location permissions on first launch

3. Users can now ask for directions in natural language and receive descriptive, landmark-enhanced navigation instructions
