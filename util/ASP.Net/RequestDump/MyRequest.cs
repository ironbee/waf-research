using System;
using System.Collections.Generic;
using System.Collections;
using System.Linq;
using System.Web;

namespace RequestDump
{
    public class MyRequest
    {
        public string Method { get; set; }

        public string Path { get; set; }

        public string Protocol { get; set; }

        public List<MyParam> headers;

        public List<MyParam> queryParams;

        public List<MyParam> bodyParams;

        public List<MyParam> cookies;

        public List<MyFile> files;

        public MyRequest()
        {
            headers = new List<MyParam>();
            queryParams = new List<MyParam>();
            bodyParams = new List<MyParam>();
            cookies = new List<MyParam>();
            files = new List<MyFile>();
        }

        public void AddHeader(MyParam h)
        {
            headers.Add(h);            
        }

        public void AddQueryParam(MyParam h)
        {
            queryParams.Add(h);
        }

        public void AddBodyParam(MyParam h)
        {
            bodyParams.Add(h);
        }

        public void AddCookie(MyParam h)
        {
            cookies.Add(h);
        }

        public void AddFile(MyFile f)
        {
            files.Add(f);
        }
    }    
}