//
// Copyright (coffee) 2012, J2 Innovations
// All Rights Reserved
//
// History:
//   14 June 2013  Radu Dita  Creation
//

using haystack
using connExt

@Js
const class KNXModel : ConnModel
{
  const private Bool enablePolling

  new make(Bool enablePolling := true) : super(KNXModel#.pod)
  {
    this.enablePolling = enablePolling
    this.connProto = Etc.makeDict([
     "dis": "KNX Conn",
     "knxConn": Marker.val,
     "uri": `knx://ip`])
  }

  override const Dict connProto

  override Bool isPollingSupported()
  {
    return enablePolling
  }

  override Bool isCurSupported()
  {
    return true
  }

  override Bool isLearnSupported()
  {
    return true
  }

  override Bool isWriteSupported()
  {
    return true
  }

  override Bool isHisSupported()
  {
    return false
  }
}