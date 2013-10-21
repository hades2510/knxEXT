using fresco
using connExt
using haystack

@Js
internal class KnxApplet : ConnApplet
{
  override Bool hasPassword() { false }

  override RecCmd[] connCmds()
  {
    //[DeviceDicoveryCmd()]//,
     [ConnectorSettingsCmd()]
    //[,]
  }

  override TagSpec[] connTagSpecs()
  {
    m := Marker.val
    return [
      // hide id/mod
      TagSpec("id",  Ref#,    ["req"]),
      TagSpec("mod", DateTime#, ["req"]),

      // config tags
      TagSpec("dis",         Str#,    ["req", "summary"]),
      TagSpec("uri",         Uri#,    ["req":m, "summary":m, "defVal":`knx://ip`]),
      TagSpec("knxConn",  Marker#, ["req"]),
      TagSpec("knxPollFreq", Number#, ["req"]),
      TagSpec("knxProjectFile", Bin#, ["req","summary","hidden"]),

      // status tags
      TagSpec("knxVersion",  Str#, ["summary", "hidden"]),
      TagSpec("knxDevice",   Str#, ["summary", "hidden"]),
      TagSpec("knxClientAddress", Str#, ["summary", "hidden"]),
      TagSpec("disabled",       Str#, ["summary", "hidden"]),
      TagSpec("connStatus",     Str#, ["summary", "hidden"]),
      TagSpec("connState",      Str#, ["summary", "hidden"]),
      TagSpec("connErr",        Str#, ["summary", "hidden"]),
    ]
  }
}
