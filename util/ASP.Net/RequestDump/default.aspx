<%@ Page Language="c#"%>
<%@ Import Namespace="Newtonsoft.Json" %>
<%@ Import Namespace="WebApplication1" %>
<%

WetRequest wetRequest = new WetRequest();
wetRequest.Method = Request.HttpMethod;
wetRequest.Path = Request.Path;
wetRequest.Protocol = Request.ServerVariables["SERVER_PROTOCOL"];

int loop1, loop2;
NameValueCollection coll;
String[] arr1, arr2;

// Headers
coll = Request.Headers;
arr1 = coll.AllKeys; 
for (loop1 = 0; loop1 < arr1.Length; loop1++) 
{
    arr2 = coll.GetValues(arr1[loop1]);
    for (loop2 = 0; loop2 < arr2.Length; loop2++) {
        WetParam h = new WetParam();
        h.Name = arr1[loop1];
        h.Value = arr2[loop2];
        wetRequest.AddHeader(h);
    }
}

// Query parameters
coll = Request.QueryString;
arr1 = coll.AllKeys; 
for (loop1 = 0; loop1 < arr1.Length; loop1++) 
{
    arr2 = coll.GetValues(arr1[loop1]);
    for (loop2 = 0; loop2 < arr2.Length; loop2++) {
        WetParam h = new WetParam();
        h.Name = arr1[loop1];
        h.Value = arr2[loop2];
        wetRequest.AddQueryParam(h);
    }
}

// Body parameters
coll = Request.Form;
arr1 = coll.AllKeys; 
for (loop1 = 0; loop1 < arr1.Length; loop1++) 
{
    arr2 = coll.GetValues(arr1[loop1]);
    for (loop2 = 0; loop2 < arr2.Length; loop2++) {
        WetParam h = new WetParam();
        h.Name = arr1[loop1];
        h.Value = arr2[loop2];
        wetRequest.AddBodyParam(h);
    }
}

// Cookies
HttpCookieCollection MyCookieColl;
HttpCookie MyCookie;
MyCookieColl = Request.Cookies;

arr1 = MyCookieColl.AllKeys;
for (loop1 = 0; loop1 < arr1.Length; loop1++) 
{
   MyCookie = MyCookieColl[arr1[loop1]];   
   arr2 = MyCookie.Values.AllKeys;
   for (loop2 = 0; loop2 < arr2.Length; loop2++) 
   {        
        WetParam h = new WetParam();
        h.Name = MyCookie.Name;
        h.Value = MyCookie.Values[loop2];
        wetRequest.AddCookie(h);      
   }
}

// Files
HttpFileCollection Files;
Files = Request.Files;
arr1 = Files.AllKeys;
for (loop1 = 0; loop1 < arr1.Length; loop1++) 
{
    WetFile f = new WetFile();
    f.Name = arr1[loop1];
    f.Size = Files[loop1].ContentLength;
    f.ContentType = Files[loop1].ContentType;

    byte[] buffer = new byte[f.Size];
   
    System.IO.Stream MyStream = Files[loop1].InputStream;
    MyStream.Read(buffer, 0, f.Size);    
    f.Data = Encoding.UTF8.GetString(buffer, 0, buffer.Length);
    wetRequest.AddFile(f);    
}

Response.ContentType = "text/plain";
Response.Clear();
string json = JsonConvert.SerializeObject(wetRequest, Formatting.Indented);
Response.Write(json);

%>
