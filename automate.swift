// created by psksvp@gmail.com
// to automate On The Grassland,
// http://psksvp.gitlab.io/hsdsme/mpt.html

import Foundation
import CommonSwift
import SwiftSoup

//let prefix = "/Users/psksvp/workspace/OnTheGrassLand/hsdsDev"
let prefix = "."
let versionFilePath = "\(prefix)/version.int"
let mdFilesPath = "\(prefix)/md"
let docsPath = "\(prefix)/docs"
let sitePath = "\(prefix)/site"
let date = ["/bin/date"].spawn()!.trim()
let version = FS.readText(fromLocalPath: versionFilePath)!.trim()
let mdTocFile = "\(docsPath)/text/ch007-\(version).xhtml"
let leftTriangle = "&#9664;" // ◀
let rightTriangle = "&#9654;" // ▶

let cachePolicyTags = """
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="0" />
"""


main()



func main()
{
  Log.throwOnError = true
  Log.info("Running on \(date) and version \(version)")
  guard CommandLine.argc > 1 else
  {
    Log.info("no command")
    return
  }
  
  
  switch CommandLine.arguments[1]
  {
    case "toSite"      : transformToSite("\(docsPath)/nav.xhtml")
    case "versioning"  : versioning()
                         insertNavToPages()
    case "+version"    : updateVersionFile()
    case "verEPUB"     : verEPUB()
    case "seqNav"      : insertNavToPages()
    default            : Log.warn("don't know option \(CommandLine.arguments[1])")
  }
}

func verEPUB()
{
  let files = [("\(mdFilesPath)/title.raw.yaml", "\(mdFilesPath)/title.yaml"),
               ("\(mdFilesPath)/title.raw.md",   "\(mdFilesPath)/title.md"),
               ("\(mdFilesPath)/version.raw.md", "\(mdFilesPath)/version.md"),
               ("\(mdFilesPath)/download.html", "\(docsPath)/download.html"),
               ("\(mdFilesPath)/README.raw.md",  "./README.md")]
  
  for (raw, out) in files
  {
    Log.info("versioning for epub \(raw) -> \(out)")
    versionFile(raw, out)
  }
  versionCoverImage("\(mdFilesPath)/cover.raw.png", "\(mdFilesPath)/cover.png")
}

func aHref(_ title: String, _ href:String) -> String?
{
  guard !href.isEmpty && !title.isEmpty else {return nil}
  
  return "<a href=\"\(href)\">\(title)</a>"
}

func insertNavToPages()
{
  func navBar(_ cur: String,
              previous: (String, String)? = nil,
              next: (String, String)? = nil) -> String
  {
    let (prevTitle, prevHREF) = previous ?? ("", "")
    let prevSide = aHref("\(leftTriangle) \(prevTitle)", prevHREF) ?? ""
    
    let (nextTitle, nextHREF) = next ?? ("", "")
    let nextSide = aHref("\(nextTitle) \(rightTriangle)", nextHREF) ?? ""
    
    return """
    <table style="width:100%;table-layout: fixed;">
    <tr>
    <td style="text-align:left;width:30%;">\(prevSide)</td>
    <td style="text-align:center;width:40%;">\(cur)</td>
    <td style="text-align:right;width:30%;">\(nextSide)</td>
    </tr>
    </table>
    """.replacingOccurrences(of: "text/", with: "")
  }
  
  //////////
  
  func augFile(_ cur: (String, String),
               previous: (String, String)? = nil,
               next: (String, String)? = nil,
               topSearchString: String = "<body epub:type=\"bodymatter\">")
  {
    let file = String("\(docsPath)/\(cur.1)".split(separator: "#")[0])
    let tbl = navBar(cur.0, previous: previous, next: next)
    let s1 = "\(topSearchString)\n\(tbl)\n<hr></hr>\n"
    let s2 = "<hr></hr>\n\(tbl)\n</body>"
    Log.info("going to aug file \(file) for nav bar \(cur)")
    let html = FS.readText(fromLocalPath: file)!
    let augHTML = html.replacingOccurrences(of: topSearchString,with: s1)
                      .replacingOccurrences(of: "</body>", with: s2)
    FS.writeText(inString: augHTML, toPath: file)
  }
  
  //////////
  let nav = liftNav("\(docsPath)/nav.xhtml")!
  guard nav.count >= 2 else
  {
    Log.error("nav.count < 2")
    return
  }
  
  augFile(nav[0], next: nav[1], topSearchString: "<body id=\"cover\">")
  for i in 1 ..< nav.count - 1
  {
    augFile(nav[i], previous: nav[i - 1], next: nav[i + 1])
  }
  augFile(nav.last!, previous: nav[nav.count - 2])
}


func versioning()
{
  var rpl:[(String, String)] = []
  
  for f in ls("\(docsPath)/text")
  {
    let (file, content) = versionContent("\(docsPath)/text/\(f)")!
    FS.writeText(inString: content, toPath:"\(docsPath)/text/\(file)")
    Log.info("content versioning \(file)")
    rpl.append( (String(f), file) )
    if let _ = f.range(of: "ch")
    {
      rm("\(docsPath)/text/\(f)")
    }
  }
  
  for f in ls("\(docsPath)/text")
  {
    let path = "\(docsPath)/text/\(f)"
    let text = FS.readText(fromLocalPath: path)!
    let nt = searchAndReplace(rpl, inString: text)
    FS.writeText(inString: nt, toPath: path)
    Log.info("fixing href in \(f)")
  }
  
  let navText = FS.readText(fromLocalPath: "\(docsPath)/nav.xhtml")!
  let newNavText = searchAndReplace(rpl, inString: navText)
  FS.writeText(inString: newNavText, toPath: "\(docsPath)/nav.xhtml")
  FS.writeText(inString: version, toPath: "\(docsPath)/version.int")
}

func versionContent(_ contentFile:String) -> (String, String)?
{
  let xhtml = FS.readText(fromLocalPath: contentFile)!
  
  func doCoverOrTitle() -> (String, String)?
  {
    let rpl = searchAndReplace([("<title>On The Grassland</title>",
                                 "<title>On The Grassland</title>\n\(cachePolicyTags)\n<version>\(version)</version>")],
                               inString: xhtml)
    return (String(contentFile.split(separator: "/").last!), rpl)
  }
  
  func doChapter() -> (String, String)?
  {
    do
    {
      let doc = try SwiftSoup.parse(xhtml)
      let title = try doc.select("title").first()!
      let text = try title.text()
      let section = try doc.select("section").first()!
      let name = try section.attr("id")
      let dataNo = try section.attr("data-number")
      
      let rpl = searchAndReplace([("<title>\(text)</title>",
                                   "<title>\(name)\(dataNo)</title>\n\(cachePolicyTags)\n<version>\(version)</version>")],
                                 inString: xhtml)
      
      let fileNoExt = text.split(separator: ".").first!
      return ("\(fileNoExt)-\(version).xhtml", rpl)
    }
    catch Exception.Error(_, let message)
    {
      Log.error(message)
    }
    catch
    {
      Log.error("unknown error")
    }
    return nil
  }
  
  if let _ = contentFile.range(of: "ch")
  {
    return doChapter()
  }
  else
  {
    return doCoverOrTitle()
  }
}

func versionFile(_ inFile: String, _ outFile: String)
{
  let srPair = [("DATE", date), ("VERSION", version)]
  if let text = FS.readText(fromLocalPath: inFile)
  {
    let r = searchAndReplace(srPair, inString: text)
    FS.writeText(inString: r, toPath: outFile)
  }
  else
  {
    Log.error("Fail to read file \(inFile)")
  }
}

func versionCoverImage(_ imagePath:String, _ outputPath:String)
{
  ["/usr/local/bin/convert", imagePath, "-background", "Khaki",
   "label:'Version \(version) \(date)'", "+swap",
   "-gravity", "Center", "-append", outputPath].spawn()
}

func updateVersionFile()
{
  if let v = Int(version)
  {
    let nv = String(v + 1)
    FS.writeText(inString: nv, toPath: versionFilePath)
  }
  
  let v = catRead(versionFilePath)
  Log.info("version.int is updated to \(v)")
}


func transformToSite(_ tocFile: String)
{
  let navHTML = navText(tocFile)!
  let navList = liftNav(tocFile)!
  let jsPages = (navList.map{"'\($0.1)'"}).joined(separator: ",")
  
  let zmRawHTML = FS.readText(fromLocalPath: "\(sitePath)/zm.raw.html")!
  let zmHTML = searchAndReplace([("__NAV_TEXT__", navHTML),
                                 ("__PAGES__", jsPages)], inString: zmRawHTML)
  FS.writeText(inString: zmHTML, toPath: "\(docsPath)/zm.html")
  fixMdTOC(mdTocFile)
}

func navText(_ navFile: String) -> String?
{
  let start = """
  <nav epub:type="toc" id="toc">
  """
  let end = "</nav>"
  
  if let text = readNavText(navFile),
     let s = text.range(of: start),
     let e = text.range(of: end)
  {
    let r = text[s.upperBound ..< e.lowerBound]
    return String(r)
  }
  else
  {
    Log.error("something went wrong")
    return nil
  }
}

func readNavText(_ tocFile: String) -> String?
{
  let pat = #"<a\s+(?:[^>]*?\s+)?href=(["'])(.*?)\1"#
  if let nav = FS.readText(fromLocalPath: tocFile)
  {
    let srPair = nav.regexLiftPattern(pat).map{(String($0.1), "\(String($0.1)) target=\"content\"")}
    let newnav = searchAndReplace(srPair, inString: nav)
    return newnav
  }
  else
  {
    Log.error("fail to read \(tocFile)")
    return nil
  }
}

func liftNav(_ navFile: String) -> [(String, String)]?
{
  let nav = FS.readText(fromLocalPath: navFile)!
  do
  {
    let doc = try SwiftSoup.parse(nav)
    let links = try doc.select("a")
    let m = try links.map { (try $0.text(), try $0.attr("href")) }
    return [m.last!] + m.dropLast() // was last, so move to first.
  }
  catch Exception.Error(_, let message)
  {
    Log.error(message)
  }
  catch
  {
    Log.error("unknown error")
  }
  
  return nil
}

func fixMdTOC(_ mdtocFile:String)
{
  let html = FS.readText(fromLocalPath: mdtocFile)!
  do
  {
    let doc = try SwiftSoup.parse(html)
    let section = try doc.select("section")
    let name = try section.attr("id")
    if name != "table-of-contents"
    {
      Log.error("file \(mdtocFile) was not generated from toc.md")
      return
    }
    
    let links = try doc.select("a")
    let slr = try links.map
    {
       (try $0.attr("href"),
       String("../zm.html#" + (try $0.attr("href")).split(separator: "#")[1] + "\" target=\"_blank"))
    }
    
    let newMdToc = searchAndReplace(slr, inString: html)
    FS.writeText(inString: newMdToc, toPath: mdtocFile)
    Log.info("wrote newMdToc to \(mdtocFile)")
  }
  catch Exception.Error(_, let message)
  {
    Log.error(message)
  }
  catch
  {
    Log.error("unknown error")
  }
}



func searchAndReplace(_ p: [(String, String)], inString: String) -> String
{
  if p.count > 0
  {
    let (s, r) = p[0]
    let rs = inString.replacingOccurrences(of: s, with: r)
    return searchAndReplace(Array(p.dropFirst(1)), inString: rs)
  }
  else
  {
    return inString
  }
}

func moveFile(_ from: String, _ to: String)
{
  ["/bin/mv", from, to].spawn()
}

func catRead(_ path: String) -> String
{
  return ["/bin/cat", path].spawn()!
}

func catWrite(_ s: String, _ path: String)
{
  ["/bin/cat", ">", path].spawn(stdInput: s)
}

func ls(_ dir: String) -> [Substring]
{
  return ["/bin/ls", dir].spawn()!.split(separator: "\n")
}

func cp(_ f: String, t: String)
{
  ["/bin/cp", f, t].spawn()
}

func rm(_ f: String)
{
  ["/bin/rm", "-f", f].spawn()
}



 

