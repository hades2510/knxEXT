using webfwt

@Js
internal class ConnFileUploader : FileUploader
{
  new make(Str id):super()
  {
    this.uri = Uri("/api/demo/ext/knx/"+id)
  }
  
}
