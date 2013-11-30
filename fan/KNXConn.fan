using haystack
using connExt
using xml
using xmlExt
using proj

using [java]fanx.interop

using [java]com.uberknx
using [java]com.uberknx.response
using [java]com.uberknx.payload

class KnxConn : Conn
{
  private KNXConnection? connection := null
  private Str? ip := null
  private Int? port := null
  private Str? discoveryXML := null
  private Grid? knxPoints := null
  private Dict xmls := Etc.emptyDict()
  private Str dataFilePath := ""
  
  new make(ConnActor actor, Dict rec): super(actor, rec)
  {
    ip = (rec["uri"] as Uri).host
    port = (rec["uri"] as Uri).port
    
    if( port == null )
    {
      port = 3671
    }
    
    connection = KNXConnection(ip, port)
    
    log.info("KNX Connection ip = " + ip)
    log.info("KNX Connection port = " + port)
    log.info("KNX Connection conn = " + connection)
    //log.info("KNX Connection root = " + elem)
  }
  
  Void parseZip( Zip zip )
  {
    File? entry
    
    xmls = Etc.emptyDict()
    
    //for every file get the stuff :D
    while( ( entry = zip.readNext() ) != null )
    {
      if( entry.uri().parent().toStr() == "/")
      {
        if( entry.uri().name().getRange(-3..-1) == "xml" )
        {
          dataFilePath = "/"+entry.uri().name()
        }
      }
      if( entry.uri().name().getRange(-3..-1).compare("xml") == 0 )
      {
        //TO DO - find out why this hack is needed
        xmls = Etc.dictSet( xmls, entry.uri().toStr(), entry.readAllStr().getRange(1..-1) )
      }
    }
    
    //get the project file first, so we can get the project id, and get the xml with the topology
    xmls.each |val, key| 
    { 
      Uri ukey := Uri.fromStr((Str)key)
      
      log.info(key)
      
      if( ukey.name() == "Project.xml" )
      {    
        XElem projRoot := XmlLib.xmlRead( (Str)val )
        Str? projId := projRoot.elem("Project").elem("ProjectInformation").attr("ProjectId").val
        
        //different kind of project, get the id using a different path
        if( projId == null || projId == "0" )
        {
          projId = projRoot.elem("Project").attr("Id").val
        }
        
        log.info("Project id: "+projId)
        
        Str projFileParent := ukey.parent().toStr()
        //path for project file
        Str projFilePath := projFileParent+"0.xml"
        //parse it :)
        Str projXml := xmls[projFilePath]
        parseXml( projXml )
      }
    }
  }
  
  Void parseXml( Str? discoveryXML )
  {
    Str? elem := "";
    
    XElem dataRoot := XmlLib.xmlRead( xmls[dataFilePath] )
    
    if( discoveryXML != null )
    {
      XElem root := XmlLib.xmlRead( discoveryXML )
      XElem topology := root.elem("Project").elem("Installations").elem("Installation").elem("Topology")
      XElem addresses := root.elem("Project").elem("Installations").elem("Installation").elem("GroupAddresses").elem("GroupRanges")
      //get every group address first, so we can refer to it if we need it
      
      //map for storing the group address
      Dict knxAddresses := Etc.emptyDict()
      Dict knxAddressesName := Etc.emptyDict()
      
      addresses.each |maingroup|
      {
        XElem nMaingroup := (XElem)maingroup
        
        nMaingroup.each |middlegroup|
        {
          XElem nMiddlegroup := (XElem)middlegroup
          
          nMiddlegroup.each |subgroup|
          {
            XElem xaddress := (XElem)subgroup
            knxAddresses = Etc.dictSet(knxAddresses, xaddress.attr("Id").val, xaddress.attr("Address").val)
            knxAddressesName = Etc.dictSet(knxAddressesName, xaddress.attr("Id").val, xaddress.attr("Name").val)
          }
        }
      }
     
      //devices
      Dict[] rows := [,]
      //each area
      topology.each |area| 
      { 
        XElem nArea := (XElem)area
        XAttr areaAddress := nArea.attr("Address")
        
        //each line
        nArea.each |line|
        {
          XElem nLine := (XElem)line
          XAttr lineAddress := nLine.attr("Address")
          
            /*
            dis: display name for navigation
            learn: optional arg to dive down into new level
            point: marker indicating point (1 or more fooCur/His/Write)
            fooCur: address if object can be mapped for cur real-time sync
            fooWrite: address if object can be mapped for writing
            fooHis: address if object can be mapped for history sync
            curRef: Ref to point already mapped by fooCur
            writeRef: Ref to point already mapped by fooWrite
            hisRef: Ref to point already mapped by fooHis
            kind: point kind type if known
            unit: point unit if known
            hisInterpolate: if point is known to be collected as COV
            enum: if range of bool or multi-state is known
            other columns which may be used by conn specific learn screen
          */
          
          //each point
          nLine.each |point|
          {
            XElem nPoint := (XElem)point
            XAttr? pointAddress := nPoint.attr("Address", false)
            
            //no address for this point, it may just be present in the project
            //but it's not accessible, like a power source
            if( pointAddress == null )
            {
              return
            }
            
            Dict row := Etc.emptyDict()
            
            row = Etc.dictSet(row, "dis", "KNX Device : " + getDeviceNameFromRef(nPoint.attr("ProductRefId").val) )
            row = Etc.dictSet(row, "fooCur", areaAddress.val + "/" + lineAddress.val + "/" + pointAddress.val )
            row = Etc.dictSet(row, "point", false)
                        
            rows.add( row )
            
            //maybe we have points available on this device
            nPoint.each |pointChild|
            {
              if( pointChild.nodeType == XNodeType.elem )
              {
                XElem nPointChild := (XElem)pointChild
                
                //we may have some points
                if( nPointChild.name == "ComObjectInstanceRefs" )
                {
                  
                  //for each ref look for children
                  nPointChild.each |commref|
                  {
                    XElem comObjInstance := (XElem)commref
                    
                    ((XElem)commref).each |connector|
                    {
                      row = Etc.emptyDict()
                      
                      //com object ref
                      Str commRef := comObjInstance.attr("RefId").val
                      Str manId := commRef.split('_')[0]
                      Str appId := commRef.split('_')[1]
                      Str deviceXmlPath := "/"+manId+"/"+manId+"_"+appId+".xml"
                      
                      //the string representation of the xml
                      Str deviceXmlStr := xmls[deviceXmlPath]
                      
                      //the xml that we'll use if the info for comm channels is not available
                      //in the ComObjectInstanceRef, this happens often
                      XElem deviceXml := XmlLib.xmlRead( deviceXmlStr )
                      
                      //address and stuff for the point
                      Str addressRef := ((XElem)connector).elem("Send").attr("GroupAddressRefId").val
                      Str realAddress := knxAddresses.get(addressRef)
                      Str addressName := knxAddressesName.get(addressRef)
                      Dict connDict := Etc.emptyDict()
                      ConnPoint pointToAdd := ConnPoint(this, connDict)
                      
                      Str dataSize := getDataSize( deviceXml, manId, appId, commRef )
                      
                      row = Etc.dictSet(row, "data", dataSize)
                      row = Etc.dictSet(row, "dis", "Point (" + addressName + ") / " + realAddress )
                      row = Etc.dictSet(row, "point", true)
                      row = Etc.dictSet(row, "knxData", dataSize)
                      
                      //let's see if the point has WriteFlag set
                      if( nPointChild.attr("WriteFlag", false) != null )
                      {
                        row = Etc.dictSet(row, "knxWrite", KNXAddressToStr ( intToKNXAddress(Int.fromStr(realAddress) ) ) + "@" + dataSize)
                        row = Etc.dictSet(row, "knxWriteLevel", Number.makeNum(8))
                      }
                      else
                      {
                        //we need to check the WriteFlag in the ComObject or in the ComObjectRef used
                        Bool isWriteEnabled := isWriteEnabled( deviceXml, manId, appId, commRef )
                        
                        //awesome we can write
                        if( isWriteEnabled )
                        {
                          row = Etc.dictSet(row, "knxWrite", KNXAddressToStr ( intToKNXAddress(Int.fromStr(realAddress) ) ) + "@" + dataSize)
                          row = Etc.dictSet(row, "knxWriteLevel", Number.makeNum(8))
                        }
                      }
                      
                      //let's see if the point has ReadFlag set 
                      if( nPointChild.attr("ReadFlag", false) != null )
                      {
                        row = Etc.dictSet(row, "knxCur",KNXAddressToStr ( intToKNXAddress(Int.fromStr(realAddress) ) ) + "@" + dataSize)
                      }
                      else
                      {
                        //we need to check the ReadFlag in the ComObject or in the ComObjectRef used
                        Bool isReadEnabled := isReadEnabled( deviceXml, manId, appId, commRef )
                        
                        //awesome we can write
                        if( isReadEnabled )
                        {
                          row = Etc.dictSet(row, "knxCur",KNXAddressToStr ( intToKNXAddress(Int.fromStr(realAddress) ) ) + "@" + dataSize)
                        }
                      }
                      
                      row = Etc.dictSet(row, "kind", "Number")
                      row = Etc.dictSet(row, "unit", "mV")
                      
                      rows.add(row)
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      knxPoints = Etc.toGrid( rows )
    }
  }
  
  
  //returns true if the commObject or commObjectRef has write enabled
  Bool isWriteEnabled( XElem root, Str manId, Str appId, Str commRef )
  {
    List comm := getComObjRef( root, manId, appId, commRef )
    XElem commObjRef := comm[0]
    XAttr? writeFlag := commObjRef.attr("WriteFlag", false)
    
    if( writeFlag == null )
    {
      //get the commObj and take a look over there
      XElem commObj := comm[1]
      
      writeFlag = commObj.attr("WriteFlag", false)
      
      if( writeFlag == null )
      {
        return false
      }
      else
      {
        if( writeFlag.val == "Disabled" )
        {
          return false
        }
        else
        {
          return true
        }
      }
    }
    else
    {
      //the value is in the freaking commOjRef 
      if( writeFlag.val == "Disabled" )
      {
        return false;
      }
      else
      {
        return true;
      }
    }
    
    return false
  }
  
  //returns true if the commObject or commObjectRef has read enabled
  Bool isReadEnabled( XElem root, Str manId, Str appId, Str commRef )
  {
    List comm := getComObjRef( root, manId, appId, commRef )
    XElem commObjRef := comm[0]
    XAttr? readFlag := commObjRef.attr("ReadFlag", false)
    
    if( readFlag == null )
    {
      //get the commObj and take a look over there
      XElem commObj := comm[1]
      
      readFlag = commObj.attr("ReadFlag", false)
      
      if( readFlag == null )
      {
        return false
      }
      else
      {
        if( readFlag.val == "Disabled" )
        {
          return false
        }
        else
        {
          return true
        }
      }
    }
    else
    {
      //the value is in the freaking commOjRef 
      if( readFlag.val == "Disabled" )
      {
        return false;
      }
      else
      {
        return true;
      }
    }
    
    return false
  }
  
  //return the data size for the current object 
  Str getDataSize( XElem root, Str manId, Str appId, Str commRef )
  {
    List comm := getComObjRef( root, manId, appId, commRef )
    XElem commObjRef := comm[0]
    XAttr? dataSize := commObjRef.attr("ObjectSize", false)
    
    if( dataSize == null )
    {
      //get the commObj and take a look over there
      XElem commObj := comm[1]
      
      dataSize = commObj.attr("ObjectSize", false)
      
      return dataSize.val
    }
    else
    {
      return dataSize.val
    }
    
    return ""
  }
  
  //parses the XML located at root and returns the commRef needed 
  Obj? getComObjRef(XElem root, Str manId, Str appId, Str commRef)
  {
    XElem manData := root.elem("ManufacturerData")
    List ret := [,]
    
    manData.each| XElem manufacturer |
    {
      //only go the manufacturer that we want
      if( manufacturer.attr("RefId").val.compare( manId ) == 0 )
      {
        XElem apps := (XElem)manufacturer.elem("ApplicationPrograms")
        
        //filter the apps for the one with the id that we want
        apps.each| XElem appProg |
        {
          //the app we want
          if( appProg.attr("Id").val.compare( manId +"_"+appId ) == 0 )
          {
            XElem commObjectRefs := (XElem) appProg.elem("Static").elem("ComObjectRefs")
            
            //find the commObjectRef that we need
            commObjectRefs.each|XElem commObjRef|
            {
              //the ref we want :)
              if( commObjRef.attr("Id").val.compare(commRef) == 0 )
              {
                ret.push( commObjRef )
                
                //now find and get the comm object also
                XElem commObjs := (XElem) appProg.elem("Static").elem("ComObjectTable")
                
                commObjs.each|XElem commObj|
                {
                  if( commObj.attr("Id").val.compare( commObjRef.attr("RefId").val ) == 0 )
                  {
                    ret.push( commObj )
                  }
                }
              }
            }
          }
        }
      }
    }
    
    return ret
  }
  
  Str getDeviceNameFromRef( Str ref )
  {
    XElem dataRoot := XmlLib.xmlRead( xmls[dataFilePath] )
    
    Str manId := ref.getRange(0..5)
    Str man := ""
    Str deviceName := ref.getRange(9..-1)
    deviceName = deviceName.replace(".", "%")
    deviceName = Uri.decode( deviceName ).toStr()
    
    dataRoot.elem("MasterData").elem("Manufacturers").each |node|
    { 
      XElem nodeX := (XElem)node
      
      if( nodeX.attr("Id").val.compare( manId ) == 0 )
      {
        man = nodeX.attr("Name").val
      }
    }
    
    return deviceName + " "+ "("+man+")"
  }
  
  override Void onClose()
  {
    connection.close()
  }
  
  override Void onOpen()
  {
    log.info("KNX Connection::onOpen " + connection)
    
    //updateCurConn("opening","unknown")
    Bool res := connection.start()
    
    if( res )
    {
      this.close( Err("Host unreachable") )
    }
    else
    {
      
    }
    //isOpen = true
  }
  
  override Duration? pollFreq()
  {
    try
    {
      tag := rec["knxPollFreq"] as Number
      
      if (tag != null) 
      {
        duration := tag.toDuration()
        
        if( duration == null )
        {
          return 5sec
        }
        
        if( duration < 5sec )
        {
          return 5sec
        }
        
        return duration
      }
      else
      {
        return 5sec
      }
    }
    catch (Err e) {}
    
    return 5sec
  }
  
  override Void onWrite(ConnPoint point, Obj? val, Number level)
  {
    log.info("KNX Connection::onWrite "+point)
    
    if( val == null )
    {
      return
    }
    
    Int[] knxAddress := strToKNXAddress( (point.rec["knxWrite"] as Str).split('@')[0] )
    Int? value := ((Number)val).toInt()
    
    log.info( value.toStr() )
    
    Str? dataType := (point.rec["knxWrite"] as Str).split('@')[1]
    Int dataLength := Int.fromStr(dataType.split(' ')[0])
    dataType = dataType.split(' ')[1]

    //use the data type to 
    ByteArray vald := ByteArray(dataLength)
    
    Number? valueTmp := val
    
    if( dataType.contains("bytes") || dataType.contains("Bytes") )
    {
      for( Int i := dataLength-1 ; i >= 0; i-- )
      {
        vald[ i ] = value.and( 0xff )
        value = value.shiftr( 8 )
      }
         
      connection.writeValue( knxAddress[0], knxAddress[1], knxAddress[2], vald)
    }
    else
    {
      connection.writeValueSmall( knxAddress[0], knxAddress[1], knxAddress[2], valueTmp.toInt())
    }
    
    point.updateWriteOk( valueTmp.toInt().toStr(), Number.makeInt(8) )
  }
  
  override Dict onPing()
  {
    log.info("KNX Connection::onPing")
    
    KNXResponse? response := connection.search()
    DIBDevice? dib;
    
    if( response == null )
    {
      //description may be unavailable, we should do a search
      log.info("KNX Connection::onPing description")
      
      response = connection.description()
      
      if( response == null )
      {
        log.info("KNX Connection::onPing description error")
        return Etc.makeDict(["connStatus":"fault", "connErr":"Connecting failed"])
      }
      else
      {
        dib = response.getPayloadAt(0) as DIBDevice
      }
    }
    else
    {
      dib = response.getPayloadAt(1) as DIBDevice
    }
    
    ByteArray address := connection.getKNXAddress()
    
    values := ["knxDevice" : dib.name, 
      "knxClientAddress" : (address[0].shiftr(4).and(0x0f)).toStr()+"."+(address[0].and(0x0f)).toStr()+"."+address[1].and(0xff).toStr(),
      "knxVersion" : "1.0"]
    
    log.info("KNX Connection::onPing address "+(address[0].shiftr(4).and(0x0f)).toStr()+"."+(address[0].and(0x0f)).toStr()+"."+address[1].and(0xff).toStr())
    
    Dict ret := Etc.makeDict(values)
    
    return ret
  }
  
  override Grid onLearn(Obj? arg)
  {
    log.info("KNX Connection::onLearn")
    
    Proj project := proj()
    Dict row := proj.readById( Ref(id) )
    
    InStream stream := project.readBin( row, "knxProjectFile")
    
    Zip zip := Zip.read( stream )

    parseZip( zip )
    
    zip.close()
    
    stream.close()
    
    return knxPoints
  }
  
  override Void onPoll()
  {
    log.info("KNX Connection::onPoll")
    
    pointsWatched.each |ConnPoint p| 
    { 
      Int[] knxAddress := strToKNXAddress( (p.rec["knxCur"] as Str).split('@')[0]  )
      
      KNXResponse response := connection.getValueFromAddress( knxAddress[0], knxAddress[1], knxAddress[2] )
      EMIFrame? frame := response.getPayloadAt(1) as EMIFrame
      ByteArray? data := frame.getData()
      
      Int curVal := 0
      
      for( Int i := 0; i<data.size(); i++ )
      {
        curVal = curVal.shiftl(8)
        curVal += data.get(i).and(0xff)
      }
      
      p.updateCurOk(curVal.toStr())
    }
  }
  
  //translates an integer address to a 3 tier knx address
  Int[] intToKNXAddress(Int address)
  {
    Int[] ret := [0,0,0]
    
    ret[0] = (address / 255).shiftr( 3 )
    ret[1] = (address / 255).and( 0x07 )
    ret[2] = address.and( 0xff )
    
    return ret
  }
  
  //translates a Str address to a 3 tier knx address
  Int[] strToKNXAddress(Str address)
  {
    Str[] sa := address.split('/')
    Int[] ret := sa.map |Str s -> Int| { return Int.fromStr(s) }
   
    return ret
  }
  
  //converts a 3 tier knx address to a string representationonLearn
  
  Str KNXAddressToStr(Int[] address)
  {
    Str ret := ""
    
    ret = ret + address[0]+"/"+address[1]+"/"+address[2]
    
    return ret
  }
}