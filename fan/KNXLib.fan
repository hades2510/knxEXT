using connExt
using haystack
using proj

const class KNXLib
{
 
  @NoDoc @Axon { admin = true }
  public static Grid? knxLearn( Obj? conn, Uri? uri )
  {
    rec := SysLib.toRec(conn)
    //log.info("deviceLearn from '${rec->dis}', $uri .")
    ext := (ConnImplExt)Context.cur.ext("knx")

    try
    {
      //log.info("deviceLearn call.")
      ca := ext.connActor(rec)
      //res := ca.send(ConnMsg("deviceLearn", uri)).get(5min)
      res := KNXExt.cur.connActor(conn).learn( uri )
      return res
    }
    catch (Err err)
    {
      //log.err("device learn error: $err")
    }

    return null
  }
  
  @Axon { admin = true }
  static Obj? knxPing(Obj conn)
  {
    KNXExt.cur.connActor(conn).ping
    return null
  }
}
