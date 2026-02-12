pragma Singleton
import QtQuick

QtObject {
  id: service
  
  // Increment this to trigger refresh in all listening widgets
  property int refreshTrigger: 0
  
  function triggerRefresh() {
    refreshTrigger++;
  }
}

