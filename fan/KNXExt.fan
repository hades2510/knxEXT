// Copyright (coffee) 2012, J2 Innovations
// All Rights Reserved
//
// History:
//   14 June 2013  Radu Dita  Creation
//

using proj
using connExt
using pointExt
using web
using haystack

 @ExtMeta
{
  name     = "knx"
  icon24  = `fan://knxExt/res/img/icon24.png`
  icon72  = `fan://knxExt/res/img/icon72.png`
  depends  = [ConnExt#, PointExt#]
  licFeature = "conn"
}

const class KNXExt : ConnImplExt, Weblet
{ 
  @NoDoc new make(Proj proj) : super(proj, KNXModel(true)) {}

  static KNXExt? cur(Bool checked := true)
  {
    Context.cur.proj.ext("knx", checked)
  }
  
  override Void onPost()
  {
    log.info("on post called")
    
    InStream stream := req.in
    
    Str connid := req.uri().basename().toStr()

    Dict rec := proj.readById( Ref(connid) )
    Dict rec2 := Etc.makeDict( rec )
    
    Map values := [:]
    MimeType mime := MimeType("application/octet-stream")
    Bin bytes := Bin.make(mime.toStr)
    values.add("knxProjectFile", bytes)

    Dict vals  := Etc.makeDict(values)
    Diff diff := Diff.make(rec, vals)
    diff      = proj.commit(diff)
    row       := proj.readById(diff.id)
    
    OutStream ostream := proj.writeBin(row, "knxProjectFile", null)
    stream.pipe(ostream, null, true)

    ostream.flush
    ostream.close
    
    log.info(stream.toStr())
    
    //Diff diff := Diff.make( rec, rec2 )
    
    log.info( diff.changes.toStr() )
    
    //proj.commit( diff )
    
    res.done
  }
}
