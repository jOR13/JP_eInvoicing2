codeunit 50565 "WSProvDownloadEInvoice"
{
    Permissions = tabledata "Sales Invoice Header" = rm,
                    tabledata "Sales Cr.Memo Header" = rm;

    var
        RecEInviceEntry: Record "E-Invoice Entry";
        RecWebServicesProviderDetail: Record "Web Service Provider Detail";
        RecCompanyInfo: Record "Company Information";
        RecGeneralLedgerSetup: Record "General Ledger Setup";
        RecWebServiceProvider: Record "Web Service Provider";
        WebServiceProviderMgt: Codeunit "WS Prov Mgt.";

    procedure Code(OpcType: Text)
    var
        XMLDocWs: XmlDocument;
        Response: text;
        OutStrResponse: OutStream;
        TaxIdentification: Code[20];
        TaxIdType: Code[20];
        TaxIdNumber: Text[20];

        FileType: text;


    Begin
        RecEInviceEntry.Reset;
        RecEInviceEntry.SetFILTER("Elec. Document Status", '%1|%2', RecEInviceEntry."Elec. Document Status"::Procesado, RecEInviceEntry."Elec. Document Status"::Confirmado);
        If OpcType = '01' THEN
            RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Factura)
        else
            RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::"Nota de credito");
        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetSERESSetup();
                GetSERESMethodWS(RecWebServiceProvider.Codigo, 3);
                GetCustomerSUNAT(RecEInviceEntry."Customer No.", TaxIdentification, TaxIdType, TaxIdNumber);

                WebServiceProviderMgt.CreateWsRequestDownloadsDocuments(XMLDocWs, RecCompanyInfo, RecEInviceEntry."SUNAT DocType", RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecEInviceEntry."Document No.");
                Response := InvokeWs(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '3');
                CLEAR(RecEInviceEntry."Response Document");
                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse);
                OutStrResponse.WriteText(Response);
                RecEInviceEntry.Modify(TRUE);
                ProcessResponseWSGetDownloadConfirm(RecEInviceEntry);

            Until RecEInviceEntry.Next = 0;
        END;
    End;

    local procedure GetSERESMethodWS(SERESCode: Code[20]; MethodValue: Integer)
    var

        ErrorLb: Label 'Url Web Service is not configurated';
    begin
        RecWebServicesProviderDetail.RESET;
        RecWebServicesProviderDetail.SETRANGE(Codigo, SERESCode);
        RecWebServicesProviderDetail.SETRANGE(Metodo, MethodValue);
        IF RecWebServicesProviderDetail.FINDFIRST THEN BEGIN
            RecWebServicesProviderDetail.TestField(URL);
        END ELSE
            ERROR(ErrorLb);
    end;

    Local procedure GetCompanyInfo()
    Begin
        RecCompanyInfo.GET;
    End;

    Local Procedure GetGeneralLedgerSetup()
    Begin
        RecGeneralLedgerSetup.GET;
    End;

    local procedure GetSERESSetup()
    begin
        RecWebServiceProvider.RESET;
        RecWebServiceProvider.SETRANGE(Codigo, RecGeneralLedgerSetup."Codigo Facturacion E.");
        IF RecWebServiceProvider.FINDFIRST THEN BEGIN
            RecWebServiceProvider.TESTFIELD(Usuario);
            RecWebServiceProvider.TestField("Contraseña");
        END;
    end;

    local procedure InvokeWs(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    var
        HttpClientWs: HttpClient;
        HttpHeadersWs: HttpHeaders;
        HttpRequestWs: HttpRequestMessage;
        HttpResponseWs: HttpResponseMessage;
        HttpContentWs: HttpContent;
        StrXmlDocWs: Text;

    begin
        //DownloadXml(XmlDocWs); //TEST

        HttpContentWs.Clear();
        XmlDocWs.WriteTo(StrXmlDocWs);
        HttpContentWs.WriteFrom(StrXmlDocWs);

        HttpClientWs.Clear();
        //ABG FIX CLOUD >>
        //HttpClientWs.UseWindowsAuthentication(User, Password);
        //ABG FIX CLOUD <<

        HttpContentWs.GetHeaders(HttpHeadersWs);
        HttpHeadersWs.Clear();
        HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
        HttpHeadersWs.Add('SOAPAction', 'http://tempuri.org/IService/Obtener_PDF');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure DownloadXml(XmlDoc: XmlDocument)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        FileName: Text;

    begin
        TempBlob.CreateOutStream(OutStr);
        XMLDoc.WriteTo(OutStr);
        TempBlob.CreateInStream(InStr);
        FileName := 'original.xml';
        DownloadFromStream(InStr, 'XML FILE', '', '', FileName);

    end;

    local procedure ProcessResponseWSGetDownloadConfirm(RecInvoiceEntry: Record "E-Invoice Entry")
    var
        XmlDocResult: XmlDocument;
        TemBlob: Codeunit "Temp Blob";
        InStr: InStream;
        XMLMgt: Codeunit "SAT XML DOM Management Ext.";
        XMLNameSpaceMgt: XmlNamespaceManager;
        RootElement: XmlElement;
        XMLCurrNode: XmlNode;
        XMLElementResponse: XmlElement;
        ResultCode: Text;
        ResultB64: Text;
        PdfText: Text;
        NombrePdf: Text;
        EstadoWs: Enum "Estado Documento";

        Base64CU: Codeunit "Base64 Convert";
        TempBlobFile: Codeunit "Temp Blob";
        TempBlobZip: Codeunit "Temp Blob";
        OutStr: OutStream;
        OutStrFile: OutStream;
        ToFileName: Text;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr, TextEncoding::UTF16);

        // ToFileName := 'Descarga.txt';
        // DownloadFromStream(InStr, 'Export', '', 'All Files (*.*)|*.*', ToFileName);

        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('a', 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio');

        XmlDocResult.GetRoot(RootElement);
        RecInvoiceEntry."Response Observations" := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="Obtener_PDFResponse"]/*[local-name()="Obtener_PDFResult"]/a:ArchivoPDF', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            ResultB64 := XMLElementResponse.InnerText;

            // TempBlobZip.CreateOutStream(OutStr);
            // ConvertB64File(ResultB64, OutStr);
            // RecInvoiceEntry."Document PDF".CreateOutStream(OutStr);

            RecInvoiceEntry.CalcFields("Document PDF");

            RecInvoiceEntry."Document PDF".CreateOutStream(OutStrFile);

            Base64CU.FromBase64(ResultB64, OutStrFile);

        end Else
            ResultB64 := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="Obtener_PDFResponse"]/*[local-name()="Obtener_PDFResult"]/a:NombrePDF', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            NombrePdf := XMLElementResponse.InnerText;
        end Else
            NombrePdf := '';

        if NombrePdf <> '' then begin
            RecInvoiceEntry."Nombre Document PDF" := NombrePdf;
            RecInvoiceEntry."Elec. Document Status" := EstadoWs::Descargado;
            RecInvoiceEntry.Modify();
        end;
    END;

    local procedure GetCustomerSUNAT(CustomerNo: Code[20]; var TaxIdentification: Code[20]; var TaxIdType: Code[20]; var TaxIdNumber: Text[20])
    var
        Cust: Record Customer;
        CountryReg: Record "Country/Region";
    begin
        Cust.Reset();
        Cust.Get(CustomerNo);
        Cust.TestField("Country/Region Code");

        TaxIdType := Cust.LOCPE_DocTypeIdentitySUNAT;
        if (TaxIdType = '06') or (TaxIdType = '6') then
            TaxIdNumber := Cust."VAT Registration No."
        else
            TaxIdNumber := Cust."LOCPE_DNI/CE/Other";

        CountryReg.Reset();
        CountryReg.Get(Cust."Country/Region Code");
        TaxIdentification := CountryReg."LOCPE_Sunat Code";

    end;

    local procedure ConvertB64File(FileB64: Text; var OutStr: OutStream)
    var
        Base64Convert: Codeunit Base64Convert;

    begin
        Base64Convert.FromBase64StringToStream(FileB64, OutStr);

    end;


    local procedure ExportZipFile(var EInvoiceEntry: Record "E-Invoice Entry"; InStrZip: InStream; var InStrFile: InStream; DocType: Option "001","002"; BS64: Text)
    var
        filename: Text;
        FileMgt: Codeunit "File Management";
        SelectedFile: Text;
        TextDirectory: Label 'Select Directory';
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        DataCompression: Codeunit "Data Compression";
        ResponseOutStream: OutStream;
        EntryList: list of [Text];
        EntryListKey: Text;
        Length: Integer;
        i: Integer;

        //Save
        OutStrFile: OutStream;

    begin
        DataCompression.OpenZipArchive(InStrZip, false);
        DataCompression.GetEntryList(EntryList);

        i := 0;
        TempNameValueBuffer.DeleteAll();
        foreach BS64 in EntryList do begin
            i += 1;
            TempNameValueBuffer.Reset();
            TempNameValueBuffer.Init;
            TempNameValueBuffer.ID := i;
            TempNameValueBuffer.Name := CopyStr(FileMgt.GetFileName(EntryListKey), 1, MaxStrLen(TempNameValueBuffer.Name));
            TempNameValueBuffer."Value BLOB".CreateOutStream(ResponseOutStream);
            DataCompression.ExtractEntry(TempNameValueBuffer.Name, ResponseOutStream, Length);
            TempNameValueBuffer.Insert();
            TempNameValueBuffer."Value BLOB".CreateInStream(InStrFile);

            //Save File
            if DocType = DocType::"001" then begin
                Clear(EInvoiceEntry."Document XML");
                EInvoiceEntry."Document XML".CreateOutStream(OutStrFile);
            end else begin
                Clear(EInvoiceEntry."Document PDF");
                EInvoiceEntry."Document PDF".CreateOutStream(OutStrFile);
            end;

            // DataCompression.ExtractEntry(TempNameValueBuffer.Name, OutStrFile, Length);
            EInvoiceEntry.Modify();

        end;
    end;

    local procedure ProcessFileDataB64(var EInvoiceEntry: Record "E-Invoice Entry"; var FileB64: Text; DocType: Option "001","002")
    var
        TempBlobFile: Codeunit "Temp Blob";
        TempBlobZip: Codeunit "Temp Blob";
        OutStr: OutStream;
        OutStrFile: OutStream;
        InStr: InStream;
        InStrFile: InStream;
        LbErrorFile: Label 'Error file Base64 is not fount in  %1';
        ErrorMessage: Text;

    begin
        if FileB64 <> '' then begin
            TempBlobZip.CreateOutStream(OutStr);
            ConvertB64File(FileB64, OutStr);
            EInvoiceEntry."Document PDF".CreateOutStream(OutStr);
            OutStr.Write(FileB64);
            EInvoiceEntry.Modify();

        end else begin
            ErrorMessage := StrSubstNo(LbErrorFile, EInvoiceEntry."Document No.");
            Error(ErrorMessage);
        end;

    end;

    local procedure ValidateActiveEInvoice()
    var
        CompInfo: Record "Company Information";
        LbErrorCompany: Label 'El módulo de factura electrónica no está habilitado';
    begin
        CompInfo.Reset();
        CompInfo.Get();
        if CompInfo.Name <> 'BODEGA SAN NICOLAS' then
            Error(LbErrorCompany);

    end;

    procedure CodeConfirmacion(OpcType: Text; Serie: Text; Numero: Integer)
    var
        XMLDocWs: XmlDocument;
        Response: text;
        OutStrResponse: OutStream;
        TaxIdentification: Code[20];
        TaxIdType: Code[20];
        TaxIdNumber: Text[20];

        FileType: text;


    Begin
        RecEInviceEntry.Reset;
        RecEInviceEntry.SetRange("Elec. Document Status", RecEInviceEntry."Elec. Document Status"::Procesado);

        If OpcType = '01' THEN
            RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Factura)
        else
            RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::"Nota de credito");
        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetSERESSetup();
                GetSERESMethodWS(RecWebServiceProvider.Codigo, 3);
                GetCustomerSUNAT(RecEInviceEntry."Customer No.", TaxIdentification, TaxIdType, TaxIdNumber);

                WebServiceProviderMgt.CreateWsRequestConfirmDocuments(XMLDocWs, RecCompanyInfo, RecEInviceEntry."SUNAT DocType", RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecEInviceEntry."Document No.", Serie, Numero);
                Response := InvokeWs2(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '3');
                CLEAR(RecEInviceEntry."Response Document");
                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse);
                OutStrResponse.WriteText(Response);
                RecEInviceEntry.Modify(TRUE);
                ProcessResponseWSGetConfirm(RecEInviceEntry);

            Until RecEInviceEntry.Next = 0;
        END;
    End;

    local procedure InvokeWs2(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    var
        HttpClientWs: HttpClient;
        HttpHeadersWs: HttpHeaders;
        HttpRequestWs: HttpRequestMessage;
        HttpResponseWs: HttpResponseMessage;
        HttpContentWs: HttpContent;
        StrXmlDocWs: Text;

    begin
        //DownloadXml(XmlDocWs); //TEST

        HttpContentWs.Clear();
        XmlDocWs.WriteTo(StrXmlDocWs);
        HttpContentWs.WriteFrom(StrXmlDocWs);

        HttpClientWs.Clear();
        //ABG FIX CLOUD >>
        //HttpClientWs.UseWindowsAuthentication(User, Password);
        //ABG FIX CLOUD <<

        HttpContentWs.GetHeaders(HttpHeadersWs);
        HttpHeadersWs.Clear();
        HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
        HttpHeadersWs.Add('SOAPAction', 'http://tempuri.org/IService/ConfirmarRespuestaComprobante');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure ProcessResponseWSGetConfirm(RecInvoiceEntry: Record "E-Invoice Entry")
    var
        XmlDocResult: XmlDocument;
        TemBlob: Codeunit "Temp Blob";
        InStr: InStream;
        XMLMgt: Codeunit "SAT XML DOM Management Ext.";
        XMLNameSpaceMgt: XmlNamespaceManager;
        RootElement: XmlElement;
        XMLCurrNode: XmlNode;
        XMLElementResponse: XmlElement;
        ResultCode: Text;
        ResultB64: Text;
        PdfText: Text;
        NombrePdf: Text;
        EstadoWs: Enum "Estado Documento";

        Base64CU: Codeunit "Base64 Convert";
        TempBlobFile: Codeunit "Temp Blob";
        TempBlobZip: Codeunit "Temp Blob";
        OutStr: OutStream;
        OutStrFile: OutStream;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('a', 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio');

        XmlDocResult.GetRoot(RootElement);
        RecInvoiceEntry."Response Observations" := '';

        RecInvoiceEntry."Elec. Document Status" := EstadoWs::Confirmado;
        RecInvoiceEntry.Modify();

    END;

    procedure CodeConfirmacionRetention(Serie: Text; Numero: Text; Codigorespuesta: Text)
    var
        XMLDocWs: XmlDocument;
        Response: text;
        OutStrResponse: OutStream;
        TaxIdentification: Code[20];
        TaxIdType: Code[20];
        TaxIdNumber: Text[20];

        FileType: text;


    Begin
        RecEInviceEntry.Reset;
        RecEInviceEntry.SetRange("Elec. Document Status", RecEInviceEntry."Elec. Document Status"::Procesado);

        RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Retencion);

        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetSERESSetup();
                GetSERESMethodWS(RecWebServiceProvider.Codigo, 5);
                // GetCustomerSUNAT(RecEInviceEntry."Customer No.", TaxIdentification, TaxIdType, TaxIdNumber);

                WebServiceProviderMgt.CreateWsRequestConfirmDocumentsRetention(XMLDocWs, RecCompanyInfo, Codigorespuesta, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecEInviceEntry."Document No.", Serie, Numero);

                Response := InvokeWsRet(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '3');
                CLEAR(RecEInviceEntry."Response Document");
                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse);
                OutStrResponse.WriteText(Response);
                RecEInviceEntry.Modify(TRUE);
                ProcessResponseWSGetConfirmReten(RecEInviceEntry);

            Until RecEInviceEntry.Next = 0;
        END;
    End;

    local procedure InvokeWsRet(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    var
        HttpClientWs: HttpClient;
        HttpHeadersWs: HttpHeaders;
        HttpRequestWs: HttpRequestMessage;
        HttpResponseWs: HttpResponseMessage;
        HttpContentWs: HttpContent;
        StrXmlDocWs: Text;

    begin
        //DownloadXml(XmlDocWs); //TEST

        HttpContentWs.Clear();
        XmlDocWs.WriteTo(StrXmlDocWs);
        HttpContentWs.WriteFrom(StrXmlDocWs);

        HttpClientWs.Clear();
        //ABG FIX CLOUD >>
        //HttpClientWs.UseWindowsAuthentication(User, Password);
        //ABG FIX CLOUD <<

        HttpContentWs.GetHeaders(HttpHeadersWs);
        HttpHeadersWs.Clear();
        HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
        HttpHeadersWs.Add('SOAPAction', 'http://tci.net.pe/WS_eCica/Retencion/IServicioRetencion/ConfirmarRespuestaRetencion');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure ProcessResponseWSGetConfirmReten(RecInvoiceEntry: Record "E-Invoice Entry")
    var
        XmlDocResult: XmlDocument;
        TemBlob: Codeunit "Temp Blob";
        InStr: InStream;
        XMLMgt: Codeunit "SAT XML DOM Management Ext.";
        XMLNameSpaceMgt: XmlNamespaceManager;
        RootElement: XmlElement;
        XMLCurrNode: XmlNode;
        XMLElementResponse: XmlElement;
        ResultCode: Text;
        ResultB64: Text;
        PdfText: Text;
        NombrePdf: Text;
        EstadoWs: Enum "Estado Documento";

        Base64CU: Codeunit "Base64 Convert";
        TempBlobFile: Codeunit "Temp Blob";
        TempBlobZip: Codeunit "Temp Blob";
        OutStr: OutStream;
        OutStrFile: OutStream;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('a', 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio');

        XmlDocResult.GetRoot(RootElement);
        RecInvoiceEntry."Response Observations" := '';

        RecInvoiceEntry."Elec. Document Status" := EstadoWs::Confirmado;
        RecInvoiceEntry.Modify();

    END;

    procedure CodeReten()
    var
        XMLDocWs: XmlDocument;
        Response: text;
        OutStrResponse: OutStream;
        TaxIdentification: Code[20];
        TaxIdType: Code[20];
        TaxIdNumber: Text[20];

        FileType: text;


    Begin
        RecEInviceEntry.Reset;
        RecEInviceEntry.SetFILTER("Elec. Document Status", '%1|%2', RecEInviceEntry."Elec. Document Status"::Procesado, RecEInviceEntry."Elec. Document Status"::Confirmado);
        RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Retencion);

        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetSERESSetup();
                GetSERESMethodWS(RecWebServiceProvider.Codigo, 5);

                WebServiceProviderMgt.CreateWsRequestDownloadsDocumentsReten(XMLDocWs, RecCompanyInfo, RecEInviceEntry."SUNAT DocType", RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecEInviceEntry."Document No.");

                Response := InvokeWsRetdec(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '3');

                CLEAR(RecEInviceEntry."Response Document");
                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse, TextEncoding::UTF8);
                OutStrResponse.WriteText(Response);
                RecEInviceEntry.Modify(TRUE);

                ProcessResponseWSGetDownloadConfirmRet(RecEInviceEntry);

            Until RecEInviceEntry.Next = 0;
        END;
    End;

    local procedure InvokeWsRetdec(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    var
        HttpClientWs: HttpClient;
        HttpHeadersWs: HttpHeaders;
        HttpRequestWs: HttpRequestMessage;
        HttpResponseWs: HttpResponseMessage;
        HttpContentWs: HttpContent;
        StrXmlDocWs: Text;

    begin
        //DownloadXml(XmlDocWs); //TEST

        HttpContentWs.Clear();
        XmlDocWs.WriteTo(StrXmlDocWs);
        HttpContentWs.WriteFrom(StrXmlDocWs);

        HttpClientWs.Clear();
        //ABG FIX CLOUD >>
        //HttpClientWs.UseWindowsAuthentication(User, Password);
        //ABG FIX CLOUD <<

        HttpContentWs.GetHeaders(HttpHeadersWs);
        HttpHeadersWs.Clear();
        HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
        HttpHeadersWs.Add('SOAPAction', 'http://tci.net.pe/WS_eCica/Retencion/IServicioRetencion/ConsultarRepresentacionImpresaRetencion');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure ProcessResponseWSGetDownloadConfirmRet(RecInvoiceEntry: Record "E-Invoice Entry")
    var
        XmlDocResult: XmlDocument;
        TemBlob: Codeunit "Temp Blob";
        InStr: InStream;
        XMLMgt: Codeunit "SAT XML DOM Management Ext.";
        XMLNameSpaceMgt: XmlNamespaceManager;
        RootElement: XmlElement;
        XMLCurrNode: XmlNode;
        XMLElementResponse: XmlElement;
        ResultCode: Text;
        ResultB64: Text;
        PdfText: Text;
        NombrePdf: Text;
        EstadoWs: Enum "Estado Documento";

        Base64CU: Codeunit "Base64 Convert";
        TempBlobFile: Codeunit "Temp Blob";
        TempBlobZip: Codeunit "Temp Blob";
        LeerBlod: Codeunit "Type Helper";
        ResultGlosa: Text;
        ToFileName: Text;
        OutStr: OutStream;
        OutStrFile: OutStream;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr, TextEncoding::UTF16);

        // ToFileName := 'Descarga.txt';
        // DownloadFromStream(InStr, 'Export', '', 'All Files (*.*)|*.*', ToFileName);

        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('a', 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio');

        XmlDocResult.GetRoot(RootElement);
        RecInvoiceEntry."Response Observations" := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRepresentacionImpresaRetencionResponse"]/*[local-name()="ConsultarRepresentacionImpresaRetencionResult"]/*[local-name()="ent_Resultado"]/*[local-name()="at_ArchivoRI"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            ResultB64 := XMLElementResponse.InnerText;

            // TempBlobZip.CreateOutStream(OutStr);
            // ConvertB64File(ResultB64, OutStr);
            // RecInvoiceEntry."Document PDF".CreateOutStream(OutStr);

            RecInvoiceEntry.CalcFields("Document PDF");

            RecInvoiceEntry."Document PDF".CreateOutStream(OutStrFile);

            Base64CU.FromBase64(ResultB64, OutStrFile);

        end Else
            ResultB64 := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRepresentacionImpresaRetencionResponse"]/*[local-name()="ConsultarRepresentacionImpresaRetencionResult"]/*[local-name()="ent_Resultado"]/*[local-name()="at_NombreRI"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            NombrePdf := XMLElementResponse.InnerText;
        end Else
            NombrePdf := '';

        if NombrePdf <> '' then begin
            RecInvoiceEntry."Nombre Document PDF" := NombrePdf;
            RecInvoiceEntry."Elec. Document Status" := EstadoWs::Descargado;
            RecInvoiceEntry.Modify();
        end;
    END;

    procedure CodeConfirmacionBaja(NombreResumen: Text; TipoResumen: Text; IdResumenCliente: Text)
    var
        XMLDocWs: XmlDocument;
        Response: text;
        OutStrResponse: OutStream;
        TaxIdentification: Code[20];
        TaxIdType: Code[20];
        TaxIdNumber: Text[20];

        FileType: text;


    Begin
        RecEInviceEntry.Reset;
        RecEInviceEntry.SetRange("Elec. Document Status", RecEInviceEntry."Elec. Document Status"::Procesado);
        RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Baja);

        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetSERESSetup();
                GetSERESMethodWS(RecWebServiceProvider.Codigo, 2);

                WebServiceProviderMgt.CreateWsRequestConfirmDocumentsBaja(XMLDocWs, RecCompanyInfo, IdResumenCliente, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecEInviceEntry."Document No.", NombreResumen, TipoResumen);

                Response := InvokeWsBaja(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '3');
                CLEAR(RecEInviceEntry."Response Document");
                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse);
                OutStrResponse.WriteText(Response);
                RecEInviceEntry.Modify(TRUE);
                ProcessResponseWSGetConfirmBaja(RecEInviceEntry);

            Until RecEInviceEntry.Next = 0;
        END;
    End;

    local procedure InvokeWsBaja(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    var
        HttpClientWs: HttpClient;
        HttpHeadersWs: HttpHeaders;
        HttpRequestWs: HttpRequestMessage;
        HttpResponseWs: HttpResponseMessage;
        HttpContentWs: HttpContent;
        StrXmlDocWs: Text;

    begin
        //DownloadXml(XmlDocWs); //TEST

        HttpContentWs.Clear();
        XmlDocWs.WriteTo(StrXmlDocWs);
        HttpContentWs.WriteFrom(StrXmlDocWs);

        HttpClientWs.Clear();
        //ABG FIX CLOUD >>
        //HttpClientWs.UseWindowsAuthentication(User, Password);
        //ABG FIX CLOUD <<

        HttpContentWs.GetHeaders(HttpHeadersWs);
        HttpHeadersWs.Clear();
        HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
        HttpHeadersWs.Add('SOAPAction', 'http://tempuri.org/IService/ConfirmarRespuestaResumen');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure ProcessResponseWSGetConfirmBaja(RecInvoiceEntry: Record "E-Invoice Entry")
    var
        XmlDocResult: XmlDocument;
        TemBlob: Codeunit "Temp Blob";
        InStr: InStream;
        XMLMgt: Codeunit "SAT XML DOM Management Ext.";
        XMLNameSpaceMgt: XmlNamespaceManager;
        RootElement: XmlElement;
        XMLCurrNode: XmlNode;
        XMLElementResponse: XmlElement;
        ResultCode: Text;
        ResultB64: Text;
        PdfText: Text;
        NombrePdf: Text;
        EstadoWs: Enum "Estado Documento";

        Base64CU: Codeunit "Base64 Convert";
        TempBlobFile: Codeunit "Temp Blob";
        TempBlobZip: Codeunit "Temp Blob";
        OutStr: OutStream;
        OutStrFile: OutStream;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('a', 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio');

        XmlDocResult.GetRoot(RootElement);
        RecInvoiceEntry."Response Observations" := '';

        RecInvoiceEntry."Elec. Document Status" := EstadoWs::Confirmado;
        RecInvoiceEntry.Modify();

    END;

    var
        Cicle: integer;
}