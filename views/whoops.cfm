<cfscript>
    if ( ! structKeyExists( variables, "strLimit" ) ) {
        variables.strLimit = function( str, limit, ending = "..." ) {
            if ( len( str ) <= limit ) {
                return str;
            }
            return mid( str, 1, limit ) & ending;
        };
    }

    // Detect Session Scope
    local.sessionScopeExists = true;
    try { structKeyExists( session ,'x' ); }
    catch ( any e ) {
        local.sessionScopeExists = false;
    }
    try{
        local.thisInetHost = createObject( "java", "java.net.InetAddress" ).getLocalHost().getHostName();
    }
    catch( any e ){
        local.thisInetHost = "localhost";
    }
    var EventDetails = {
        "Error Code":        (oException.getErrorCode() != 0) ? oException.getErrorCode() : "",
        "Type":              oException.gettype(),
        "Extended":          (oException.getExtendedInfo() != "") ? oException.getExtendedInfo() : "",
        "Message":           HTMLEditFormat( oException.getmessage() ).listChangeDelims( '<br>', chr(13)&chr(10) ),
        "Detail":            HTMLEditFormat( oException.getDetail() ).listChangeDelims( '<br>', chr(13)&chr(10) ),
        "Event":             (event.getCurrentEvent() != "") ? event.getCurrentEvent() :"N/A",
        "Route":             (event.getCurrentRoute() != "") ? event.getCurrentRoute() & ( event.getCurrentRoutedModule() != "" ? " from the " & event.getCurrentRoutedModule() & "module router." : ""):"N/A",
        "Route Name":        (event.getCurrentRouteName() != "") ? event.getCurrentRouteName() :"N/A",
        "Routed Module":     (event.getCurrentRoutedModule() != "") ? event.getCurrentRoutedModule():"N/A",
        "Routed Namespace":  (event.getCurrentRoutedNamespace() != "") ? event.getCurrentRoutedNamespace() :"N/A",
        "Routed URL":        (event.getCurrentRoutedURL() != "") ? event.getCurrentRoutedURL() :"N/A",
        "Layout":            (Event.getCurrentLayout() != "") ? Event.getCurrentLayout() :"N/A",
        "Module":            event.getCurrentLayoutModule(),
        "View":              event.getCurrentView(),
        "itemorder": ["Error Code","Type","Extended","Message","Detail","Event","Route","Route Name","Routed Module","Routed Namespace", "Routed URL","Layout","Module","View"]
    }
    var frameworkSnapshot = {
        "Coldfusion ID" :"Session Scope Not Enabled",
        "Template Path" : CGI.CF_TEMPLATE_PATH,
        "Path Info"     : CGI.PATH_INFO,
        "Host"          : CGI.HTTP_HOST,
        "Server"        : local.thisInetHost,
        "Query String"  : CGI.QUERY_STRING,
        "Referrer"      : CGI.HTTP_REFERER,
        "Browser"       : CGI.HTTP_USER_AGENT,
        "Remote Address": CGI.REMOTE_ADDR,
        "itemorder": ["Coldfusion ID","Template Path","Path Info","Host","Server","Query String" ,"Referrer","Browser","Remote Address"]
    };

    if(local.sessionScopeExists) {
        var fwString = "";
        if( isDefined("client")) {
            if(structkeyExists(session, "cfid") )      fwString &= "CFID=" & client.CFID;
            if(structkeyExists(session, "CFToken") )   fwString &= "<br/>CFToken=" & client.CFToken;
        }
        if( isDefined("session") ) {
            if(structkeyExists(session, "cfid") )      fwString &= "CFID=" & session.CFID;
            if(structkeyExists(session, "CFToken") )   fwString &= "<br/>CFToken=" & session.CFToken;
            if(structkeyExists(session, "sessionID") ) fwString &= "<br/>JSessionID=" & session.sessionID;
        } 
        frameworkSnapshot["Coldfusion ID"] = fwString;
    }

    var databaseInfo = {};
    if( (
            isStruct( oException.getExceptionStruct() ) 
            OR findNoCase( "DatabaseQueryException", getMetadata( oException.getExceptionStruct() ).getName() )
          ) AND findnocase( "database", oException.getType() )
    ){
        var databaseInfo = {
          "SQL State": oException.getSQLState(),
          "NativeErrorCode": oException.getNativeErrorCode(),
          "SQL Sent": oException.getSQL(),
          "Driver Error Message": oException.getqueryError(),
          "Name-Value Pairs": oException.getWhere(),
        };

    }

    function displayScope (scope) {
        var list = '<table class="data-table"><tbody>';
        var orderedArr = scope;
        if(structKeyExists(scope,'itemorder')) orderedArr = scope.itemorder;

        for( var i in orderedArr ){
            list &= '<tr>';
            if(isDate(scope[i])){
                list &= '<td width="250">' & i & '</td>';
                list &= '<td class="overflow-scroll">' & dateformat(scope[i], "mm/dd/yyyy") & " " & timeformat(scope[i], "HH:mm:ss") & '</td>';
            } else if(isSimpleValue(scope[i])){
                list &= '<td width="250">' & i & '</td>';
                list &= '<td class="overflow-scroll">' & (scope[i]) & '</td>';
            } else {
                savecontent variable="myContent" {
                 writeDump( var = scope[i], format= "html", top=2, expand=false)
                }
                list &= '<td width="250">' & i & '</td>';
                list &= '<td class="overflow-scroll">' & myContent & '</td>';
                //list &= '<td>' & serializeJSON(scope[i]) & '</td>';
            }
            list &= '</tr>';
        }
        list &= '</tbody></table>';
        return list;
    }

    function openInEditorURL( required event, required struct instance ) {
        var editor = event.getController().getUtil().getSystemSetting( "WHOOPS_EDITOR", "" );
        switch( editor ) {
            case "vscode":
                return "vscode://file/#instance.template#:#instance.line#"
            case "vscode-insiders":
                return "vscode-insiders://file/#instance.template#:#instance.line#"
            case "sublime":
                return "subl://open?url=file://#instance.template#&line=#instance.line#";
            case "textmate":
                return "txmt://open?url=file://#instance.template#&line=#instance.line#";
            case "emacs":
                return "emacs://open?url=file://#instance.template#&line=#instance.line#";
            case "macvim":
                return "mvim://open/?url=file://#instance.template#&line=#instance.line#";
            case "idea":
                return "idea://open?file=#instance.template#&line=#instance.line#";
            case "atom":
                return "atom://core/open/file?filename=#instance.template#&line=#instance.line#";
            case "espresso":
                return "x-espresso://open?filepath=#instance.template#&lines=#instance.line#";
            default:
                return "";
        }
    }
</cfscript>

<cfset local.e = oException.getExceptionStruct() />
<cfset stackFrames = arrayLen( local.e.TagContext ) />

<cfoutput>
    <html>
    <head>
        <title>Whoops! An error occurred.</title>
        <script type="text/javascript" src="#event.getModuleRoot( "whoops" )#/includes/js/syntaxhighlighter.js"></script>
        <script type="text/javascript" src="#event.getModuleRoot( "whoops" )#/includes/js/javascript-brush.js"></script>
        <script type="text/javascript" src="#event.getModuleRoot( "whoops" )#/includes/js/coldfusion-brush.js"></script>
        <link type="text/css" rel="stylesheet" href="#event.getModuleRoot( "whoops" )#/includes/css/syntaxhighlighter-theme.css">
        <link type="text/css" rel="stylesheet" href="#event.getModuleRoot( "whoops" )#/includes/css/whoops.css">
        <script type="text/javascript">
            SyntaxHighlighter.defaults['gutter'] = true;
            SyntaxHighlighter.defaults['smart-tabs'] = false;
            SyntaxHighlighter.defaults['tab-size'] =  4;
            SyntaxHighlighter.all();
        </script>
    </head>
    <body>
        <div class="whoops">
            <div class="whoops__nav">
                <div class="exception">
                    <h1 class="exception__title">#EventDetails["Error Code"]# #local.e.type#</h1>
                    <div class="exception__message">#local.e.message#</div>
                    <small class="exception__message">#dateformat(now(), "MM/DD/YYYY")# #timeformat(now(),"hh:MM:SS TT")#</small>
                </div>
                <div class="whoops_stacktrace_panel_info">
                    Stack Frame(s): #stackFrames#
                </div>
                <div class="whoops__stacktrace_panel">
                    <ul class="stacktrace__list">
                        <cfset root = expandPath( "/" ) />
                        <cfloop from="1" to="#arrayLen( local.e.TagContext )#" index="i">
                            <cfset instance = local.e.TagContext[ i ] />
                            <!--- <cfdump var="#instance#"> --->
                            <li id="stack#stackFrames - i + 1#" class="stacktrace <cfif i EQ 1>stacktrace--active</cfif>">
                                <span class="badge">#stackFrames - i + 1#</span>
                                <div class="stacktrace__info">
                                    <h3 class="stacktrace__location">
                                        #replace( instance.template, root, "" )#:<span class="stacktrace__line-number">#instance.line#</span>
                                    </h3>
                                    <cfif structKeyExists( instance, "codePrintPlain" )>
                                        <cfset codesnippet = instance.codePrintPlain >
                                        <cfset codesnippet = rereplace(codesnippet,"\n\t"," ","All" )>
                                        <cfset codesnippet = HTMLEditFormat(  codesnippet)>
                                        <cfset codesnippet = rereplace(codesnippet,"([0-9]+:)","#chr(10)#\1","All")>
                                        <cfset splitLines  = listToArray(codesnippet,"#chr(10)#")>
                                        <h4 class="stacktrace__code" style="margin-top:-10px;">
                                            <cfloop array="#splitLines#" index="codeline">
                                                #strLimit( codeline, 40 )# <br>
                                            </cfloop>
                                        </h4>
                                    </cfif>
                                </div>
                                <cfif openInEditorURL( event, instance ) NEQ "">
                                    <a target="_self" rel="noreferrer noopener" href="#openInEditorURL( event, instance )#" class="editorLink__btn">
                                        Open
                                    </a>
                                </cfif>
                            </li>
                        </cfloop>
                    </ul>
                </div>
            </div>
            <div class="whoops__detail">
                <div class="code-preview">
                    <cfset instance = local.e.TagContext[ 1 ] />
                    <div id="code-container"></div>
                </div>
                <div class="request-info data-table-container">
                    <h2 class="details-heading">Environment &amp; details:</h2>
                    <cfoutput>
                    <div class="data-table">
                        <label>Error Details</label>
                        #displayScope(EventDetails)#
                    </div>

                    <div class="data-table">
                        <label>Framework Snapshot</label>
                        #displayScope(frameworkSnapshot)#
                    </div>
                    <div class="data-table">
                        <label>Database</label>
                        #displayScope(databaseInfo)#
                    </div>
                    <div class="data-table">
                        <label>RC</label>
                        #displayScope(rc)#
                    </div>
                    <div class="data-table">
                        <label>PRC</label>
                        #displayScope(prc)#
                    </div>
                    <div class="data-table">
                        <label>Headers</label>
                        #displayScope(getHttpRequestData().headers)#
                    </div>
                    <cftry>
                        <cfset thisSession = session />
                        <div class="data-table">
                            <label>Session</label>
                            #displayScope(thisSession)#
                        </div>
                        <cfcatch></cfcatch>
                    </cftry>
                    <div class="data-table">
                        <label>Application</label>
                        #displayScope(application)#
                    </div>
                    <div class="data-table">
                        <label>Cookies</label>
                        #displayScope(cookie)#
                    </div>
                    <div class="data-table">
                        <label>Stack Trace</label>
                        <div class="data-stacktrace">#processStackTrace( oException.getstackTrace() )#</div>
                    </div>


                    </cfoutput>
                </div>
            </div>
        </div>
        <cfloop from="1" to="#arrayLen( local.e.TagContext )#" index="i">
            <cfset instance = local.e.TagContext[ i ] />
            <cfset highlighter = "js" />
            <cfif ListLast(instance.template,".") eq "cfm"><cfset highlighter = "cf" /></cfif>
            <pre id="stack#stackFrames - i + 1#-code" data-highlight-line="#instance.line#" style="display: none;">
                <script type="syntaxhighlighter" class="brush: #highlighter#; highlight: [#instance.line#];">
                <![CDATA[<cfloop file="#instance.template#" index="line">
                #line#</cfloop>]]>
                </script>
            </pre>
        </cfloop>
        <script src="#event.getModuleRoot( "whoops" )#/includes/js/whoops.js"></script>
    </body>
    </html>
</cfoutput>
