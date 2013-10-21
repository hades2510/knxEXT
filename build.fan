using build
class Build : build::BuildPod
{
  new make()
  {
    podName = "knxExt"
    summary = "KNX Extension"
    meta    = ["org.name":       "J2 Innovations",
               "org.uri":        "http://www.j2inn.com/",
               "proj.name":      "KNXExt extension",
               "proj.uri":       "http://www.j2inn.com/",
               "j2version":      "1.0",
               "license.name":   "Commercial",
               "skyspark.docExt": "true"]
    version = Version("2.0.6.1")
    depends = ["sys 1.0",
               "concurrent 1.0",
               "util 1.0",
               "haystack 2.0",
               "proj 2.0",
               "dom 1.0",
               "fwt 1.0",
               "webfwt 1.0",
               "web 1.0+",
               "fresco 2.0",
               "connExt 2.0",
               "pointExt 2.0",
               "hisExt 2.0",
               "xml 1.0+",
               "xmlExt 1.0+",
               "knx 1.0+"]
    srcDirs = [`fan/`]
    resDirs = [`res/img/`, `lib/`, `locale/`]
    index =
    [
      "proj.ext": "knxExt::KNXExt",
      "proj.lib": "knxExt::KNXLib"
    ]
  }
}
