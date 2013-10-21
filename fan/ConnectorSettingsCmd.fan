using fresco
using fwt
using webfwt

@Js
internal class ConnectorSettingsCmd: RecCmd
{
  new make(): super.make("Connector settings") {}
  
  override Void updateEnabled() { enabled = mgr.selected.size == 1 }
  
   protected override Void invoked(Event? event)
   {
  
      Dialog(mgr.window)
      {
        title = name
        
        body  = ConstraintPane
        {
          minh=300; maxh=300
          minw=300; maxw=300
          
          Button but := Button()
          but.text = "Choose KNX project file"
          but.onAction.add( |Event e|
           {
            FileUploader fU := ConnFileUploader(mgr.selected[0].id().toStr())
            
            FileUploader.dialog( e.window(), fU ).open()   
            fU.onComplete.add |Event ev| {
             
            }
           } ) 
          
          edge := EdgePane()
          edge.center = but
          content = edge
        }
        
        commands = [Dialog.ok, Dialog.cancel]
  
      }.open
   }
}


