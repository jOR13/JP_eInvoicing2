codeunit 50561 "E-Invoice PE MGT"
{
    Permissions = tabledata "Sales Invoice Header" = rm,
                    tabledata "Sales Cr.Memo Header" = rm;

    var
        CUWebS: Codeunit "WS Prov Mgt.";
        // CUWebSRet: Codeunit "Seres Web Service Mgt. Ret";
        RecCompanyInfo: Record "Company Information";
        RecGeneralLedgerSetup: Record "General Ledger Setup";
        RecWebServiceProvider: Record "Web Service Provider";
        RecWebServicesProviderDetail: Record "Web Service Provider Detail";
        XMLMgt: Codeunit "SAT XML DOM Management Ext.";

    procedure Code(RecRef: RecordRef)
    var
        RecSalesInvoiceHeader: Record "Sales Invoice Header";
        RecSalesCRHeader: Record "Sales Cr.Memo Header";
        Error: Label 'Esta Factura fue procesada antes.';
        ErrorCM: Label 'Esta Nota de Crédito fue procesada antes.';
        FileB64: Text;

    begin
        //ValidateActiveEInvoice();

        case RecRef.Number of
            Database::"Sales Invoice Header":
                Begin
                    RecRef.SetTable(RecSalesInvoiceHeader);
                    RecSalesInvoiceHeader.CalcFields(Status);
                    IF (RecSalesInvoiceHeader.Status <> RecSalesInvoiceHeader.Status::" ") AND (RecSalesInvoiceHeader.Status <> RecSalesInvoiceHeader.Status::Enviado) THEN
                        Error(Error);
                    CreateEntryEInvoice(RecRef);
                    RecSalesInvoiceHeader.Processed := True;
                    RecSalesInvoiceHeader.Modify();
                End;
            Database::"Sales Cr.Memo Header":
                Begin
                    RecRef.SetTable(RecSalesCRHeader);
                    IF RecSalesCRHeader.Processed THEN
                        Error(ErrorCM);
                    CreateEntryEInvoice(RecRef);
                    RecSalesCRHeader.Processed := True;
                End;
        end;
    end;

    /// <summary>
    /// Evalua la creación de un Record en tabla intermedia EInvoiceEntry según tipo
    /// </summary>
    /// <param name="RecRef">Registro de referencia</param>
    local procedure CreateEntryEInvoice(RecRef: RecordRef)
    var
        RecSalesInvoiceHeader: Record "Sales Invoice Header";
        RecSalesCRHeader: Record "Sales Cr.Memo Header";
    begin
        case RecRef.Number of
            Database::"Sales Invoice Header":
                Begin
                    RecRef.SetTable(RecSalesInvoiceHeader);
                    InsertEntryInvoice(RecSalesInvoiceHeader);
                    InvokeMethod(0, RecSalesInvoiceHeader, 1);

                end;
            Database::"Sales Cr.Memo Header":
                Begin
                    // RecRef.SetTable(RecSalesCRHeader);
                    // InsertEntryCreditMemo(RecSalesCRHeader);
                    // InvokeMethodNC(1, RecSalesCRHeader, 1);
                End;
        end;
    End;

    /// <summary>
    /// Inserta un Record en EInvoiceEntry del tipo Factura
    /// </summary>
    /// <param name="RecSalesInvoiceHeader"></param>
    Local procedure InsertEntryInvoice(RecSalesInvoiceHeader: Record "Sales Invoice Header")
    var
        RecEInvoiceEntry: Record "E-Invoice Entry";
        OutStr: OutStream;
    begin
        RecEInvoiceEntry.SETRANGE("Document Type", RecEInvoiceEntry."Document Type"::Factura);
        RecEInvoiceEntry.SETRANGE("Document No.", RecSalesInvoiceHeader."No.");

        IF RecEInvoiceEntry.FindFirst THEN BEGIN
            RecEInvoiceEntry."Last Date" := Today;
            CLEAR(RecEInvoiceEntry."File Base64");
            RecEInvoiceEntry."File Base64".CreateOutStream(OutStr);
            RecEInvoiceEntry."Error Code" := '';
            RecEInvoiceEntry."Error Description" := '';
            RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";
            RecEInvoiceEntry."SUNAT DocType" := RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT";
            RecEInvoiceEntry.Modify();
            exit;
        END;

        RecEInvoiceEntry.RESET;
        RecEInvoiceEntry.INIT;
        RecEInvoiceEntry."Document Type" := RecEInvoiceEntry."Document Type"::Factura;
        RecEInvoiceEntry."Document No." := RecSalesInvoiceHeader."No.";
        RecEInvoiceEntry."Posting Date" := Today;
        RecEInvoiceEntry."User ID" := UserId;
        RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";

        RecEInvoiceEntry." Posting Date Document" := RecSalesInvoiceHeader."Posting Date";
        RecEInvoiceEntry."Customer No." := RecSalesInvoiceHeader."Bill-to Customer No.";
        RecEInvoiceEntry."Customer Name" := RecSalesInvoiceHeader."Bill-to Name";
        RecEInvoiceEntry."Custemer Name 2" := RecSalesInvoiceHeader."Bill-to Name 2";

        RecSalesInvoiceHeader.CalcFields("Amount Including VAT");

        RecEInvoiceEntry.Amount := RecSalesInvoiceHeader."Amount Including VAT";
        RecEInvoiceEntry."SUNAT DocType" := RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT";

        RecEInvoiceEntry.INSERT;


    end;

    /// <summary>
    /// Inserta un Record en EInvoiceEntry del tipo Nota de Crédito
    /// </summary>
    /// <param name="RecSalesInvoiceHeader"></param>
    Local procedure InsertEntryCreditMemo(RecSalesCrMemoHeader: Record "Sales Cr.Memo Header")
    var
        RecEInvoiceEntry: Record "E-Invoice Entry";
        OutStr: OutStream;
    begin

        RecEInvoiceEntry.SETRANGE("Document Type", RecEInvoiceEntry."Document Type"::"Nota de credito");
        RecEInvoiceEntry.SETRANGE("Document No.", RecSalesCrMemoHeader."No.");
        //RecEInvoiceEntry.SETFILTER("Error Code", '<>%1', '');
        IF RecEInvoiceEntry.FindFirst THEN BEGIN
            RecEInvoiceEntry."Last Date" := Today;
            CLEAR(RecEInvoiceEntry."File Base64");
            RecEInvoiceEntry."File Base64".CreateOutStream(OutStr);
            RecEInvoiceEntry."Error Code" := '';
            RecEInvoiceEntry."Error Description" := '';
            RecEInvoiceEntry."SUNAT DocType" := RecSalesCrMemoHeader."LOCPE_Doc. Type SUNAT";
            RecEInvoiceEntry.Modify();
            exit;
        END;

        RecEInvoiceEntry.RESET;
        RecEInvoiceEntry.INIT;
        RecEInvoiceEntry."Document Type" := RecEInvoiceEntry."Document Type"::"Nota de credito";
        RecEInvoiceEntry."Document No." := RecSalesCrMemoHeader."No.";
        RecEInvoiceEntry."Posting Date" := Today;
        RecEInvoiceEntry."User ID" := UserId;
        RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";

        RecEInvoiceEntry." Posting Date Document" := RecSalesCrMemoHeader."Posting Date";
        RecEInvoiceEntry."Customer No." := RecSalesCrMemoHeader."Bill-to Customer No.";
        RecEInvoiceEntry."Customer Name" := RecSalesCrMemoHeader."Bill-to Name";
        RecEInvoiceEntry."Custemer Name 2" := RecSalesCrMemoHeader."Bill-to Name 2";

        RecSalesCrMemoHeader.CalcFields("Amount Including VAT");

        RecEInvoiceEntry.Amount := RecSalesCrMemoHeader."Amount Including VAT";
        RecEInvoiceEntry."SUNAT DocType" := RecSalesCrMemoHeader."LOCPE_Doc. Type SUNAT";

        RecEInvoiceEntry.INSERT;
    End;

    // Local procedure InvokeMethodNC(DocumentType: Integer; RecSalesInvoiceHeaderNC: Record "Sales Cr.Memo Header"; MethodType: Option " ","Registro de Documento","Estado Documento","Descarga Documento","Actualizar Estado") response: Text
    // var
    //     RecEInvoiceentry: Record "E-Invoice Entry";

    //     XMLDoc: XmlDocument;
    //     InStr: InStream;
    //     OutStr: OutStream;
    //     FileB64: Text;
    //     TempBlob: Codeunit "Temp Blob";
    //     XMLDocResult: XmlDocument;
    //     OutStrResult: OutStream;
    //     TempBlobResult: Codeunit "Temp Blob";
    //     InStrResult: InStream;
    //     FileNameResult: Text;

    // Begin
    //     RecEInvoiceentry.RESET;
    //     RecEInvoiceentry.SETRANGE("Document Type", DocumentType);
    //     RecEInvoiceentry.SETRANGE("Document No.", RecSalesInvoiceHeaderNC."No.");
    //     IF RecEInvoiceentry.FindFirst THEN BEGIN
    //         GetCompanyInfo();
    //         GetGeneralLedgerSetup();
    //         GetWebServiceProviderSetup();
    //         GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, MethodType);
    //         CUWebS.CreateWsRequestLoadsDocumentsNC(XMLDoc, RecCompanyInfo, RecGeneralLedgerSetup, '053', RecSalesInvoiceHeaderNC, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña");

    //         response := InvokeWs(XMLDoc, '', '', RecWebServicesProviderDetail.URL, '');

    //         XmlMgt.LoadXMLDocumentFromText(Response, XMLDocResult);

    //         //DownloadXml(XMLDocResult);

    //         RecEInvoiceentry."Response Document".CreateOutStream(OutStrResult);
    //         XMLDocResult.WriteTo(OutStrResult);
    //         RecEInvoiceentry.Modify();

    //         ProcessResponseWSLoadDocument(RecEInvoiceentry);

    //     END;
    // End;


    /// <summary>
    /// LLamamiento a métodos necesarios para la creación del XML y a la creación del mismo
    /// </summary>
    /// <param name="DocumentType"></param>
    /// <param name="RecSalesInvoiceHeader"></param>
    /// <param name="MethodType"></param>
    /// <returns></returns>
    Local procedure InvokeMethod(DocumentType: Integer; RecSalesInvoiceHeader: Record "Sales Invoice Header"; MethodType: Option " ","Registro de Documento","Estado Documento","Descarga Documento","Actualizar Estado") response: Text
    var
        RecEInvoiceentry: Record "E-Invoice Entry";

        XMLDoc: XmlDocument;
        InStr: InStream;
        OutStr: OutStream;
        FileB64: Text;
        TempBlob: Codeunit "Temp Blob";
        XMLDocResult: XmlDocument;
        OutStrResult: OutStream;
        TempBlobResult: Codeunit "Temp Blob";
        InStrResult: InStream;
        FileNameResult: Text;

    Begin
        RecEInvoiceentry.RESET;
        RecEInvoiceentry.SETRANGE("Document Type", DocumentType);
        RecEInvoiceentry.SETRANGE("Document No.", RecSalesInvoiceHeader."No.");
        IF RecEInvoiceentry.FindFirst THEN BEGIN
            GetCompanyInfo();
            GetGeneralLedgerSetup();
            GetWebServiceProviderSetup();
            GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, MethodType);

            CUWebS.CreateWsRequestLoadsDocuments(XMLDoc, RecCompanyInfo, RecGeneralLedgerSetup, '053', RecSalesInvoiceHeader, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña");
            // walter

            response := InvokeWs(XMLDoc, '', '', RecWebServicesProviderDetail.URL, '');

            //parsea el response en XML (XMLDocResult)
            XmlMgt.LoadXMLDocumentFromText(Response, XMLDocResult);

            // DownloadXml(XMLDocResult);

            //El XML resultante se escribe como una var OutStream en el campo "Response Document" de E-Invoice Entry
            RecEInvoiceentry."Response Document".CreateOutStream(OutStrResult);
            XMLDocResult.WriteTo(OutStrResult);
            RecEInvoiceentry.Modify();

            //Procesamiento del resultado
            ProcessResponseWSLoadDocument(RecEInvoiceentry);

        END;
    End;

    Local procedure GetCompanyInfo()
    Begin
        RecCompanyInfo.GET;
    End;

    Local Procedure GetGeneralLedgerSetup()
    Begin
        RecGeneralLedgerSetup.GET;
    End;

    local procedure GetWebServiceProviderSetup()
    begin
        RecWebServiceProvider.RESET;
        RecWebServiceProvider.SETRANGE(Codigo, RecGeneralLedgerSetup."Servicio Facturacion E");
        IF RecWebServiceProvider.FINDFIRST THEN BEGIN
            RecWebServiceProvider.TESTFIELD(Usuario);
            RecWebServiceProvider.TestField("Contraseña");
        END;
    end;


    /// <summary>
    /// Envía la petición a la WS y devuelve un Response
    /// </summary>
    /// <param name="XmlDocWs"></param>
    /// <param name="User"></param>
    /// <param name="Password"></param>
    /// <param name="UrlWs"></param>
    /// <param name="Method"></param>-
    /// <returns></returns>
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
        // HttpHeadersWs.Add('SOAPAction', 'http://tempuri.org/IService/Registrar');
        HttpHeadersWs.Add('SOAPAction', '');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure GetWebServiceProviderMethodWS(SERESCode: Code[20]; MethodValue: Integer)
    var

        ErrorLb: Label 'Url de la Web Service no está configurado';
    begin
        RecWebServicesProviderDetail.RESET;
        RecWebServicesProviderDetail.SETRANGE(Codigo, SERESCode);
        RecWebServicesProviderDetail.SETRANGE(Metodo, MethodValue);
        IF RecWebServicesProviderDetail.FINDFIRST THEN BEGIN
            RecWebServicesProviderDetail.TestField(URL);
        END ELSE
            ERROR(ErrorLb);

    end;

    local procedure ProcessResponseWSLoadDocument(RecInvoiceEntry: Record "E-Invoice Entry")
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
        ResultObs: Text;
        Estado: Text;
        ResultDescription: Text;
        CodigoHash: Text;
        EstadoWs: Enum "Estado Documento";
        XmlDocCdata: XmlDocument;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('SOAP-ENV', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('ns3', 'http://com.conastec.sfe/ws/schema/sfe');

        XmlDocResult.GetRoot(RootElement);

        if RootElement.SelectSingleNode('//SOAP-ENV:Envelope/SOAP-ENV:Body/ns3:enviarComprobanteResponse/ns3:data', XMLNameSpaceMgt, XMLCurrNode) then begin

            XMLElementResponse := XMLCurrNode.AsXmlElement();
            XmlMgt.LoadXMLDocumentFromText(XMLElementResponse.InnerText, XmlDocCdata);

            if XmlDocCdata.SelectSingleNode('//enviarComprobanteRespuesta/codigoEstado', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                ResultCode := XMLElementResponse.InnerText;
            end Else begin
                ResultCode := '';
            end;

            if XmlDocCdata.SelectSingleNode('//enviarComprobanteRespuesta/descripcionEstado', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                ResultDescription := XMLElementResponse.InnerText;
            end Else begin
                ResultDescription := '';
            end;

            if XmlDocCdata.SelectSingleNode('//enviarComprobanteRespuesta/digestValue', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                CodigoHash := XMLElementResponse.InnerText;
            end Else begin
                CodigoHash := '';
            end;

            if XmlDocCdata.SelectSingleNode('//enviarComprobanteRespuesta/observaciones', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                ResultObs := XMLElementResponse.InnerText;
            end Else begin
                ResultObs := '';
            end;

            RecInvoiceEntry."Error Code" := '0';
            RecInvoiceEntry."Error Description" := ResultDescription;//?

            RecInvoiceEntry."Response Code" := ResultCode;
            RecInvoiceEntry."Response Web Service" := ResultDescription;
            RecInvoiceEntry."Codigo Hash" := CodigoHash;
            RecInvoiceEntry."Response Observations" := ResultObs;
            RecInvoiceEntry."Elec. Document Status" := EstadoWs::Enviado;
            RecInvoiceEntry.Modify();

            Message('Documento enviado');
            exit;

        end Else begin
            Estado := '';
        end;


        // if (Estado = 'false') then begin
        //     if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarResponse"]/*[local-name()="Cadena"]', XMLNameSpaceMgt, XMLCurrNode) then begin
        //         XMLElementResponse := XMLCurrNode.AsXmlElement();
        //         Cadena := XMLElementResponse.InnerText;
        //         Message(Cadena);
        //         RecInvoiceEntry."Response Observations" := Cadena;
        //         RecInvoiceEntry."Elec. Document Status" := RecInvoiceEntry."Elec. Document Status"::Enviado;
        //         RecInvoiceEntry.Modify();

        //         exit;
        //     end;
        // end
        // else begin
        //     if (Estado = 'true') then begin
        //         if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarResponse"]/*[local-name()="Cadena"]', XMLNameSpaceMgt, XMLCurrNode) then begin
        //             XMLElementResponse := XMLCurrNode.AsXmlElement();
        //             Cadena := XMLElementResponse.InnerText;
        //         end Else begin
        //             Cadena := '';
        //         end;
        //         if RootElement.SelectSingleNode('//s:envelope/s:Body/*[local-name()="RegistrarResponse"]/*[local-name()="CodigoHash"]', XMLNameSpaceMgt, XMLCurrNode) then begin
        //             XMLElementResponse := XMLCurrNode.AsXmlElement();
        //             CodigoHash := XMLElementResponse.InnerText;
        //         end Else begin
        //             CodigoHash := '';
        //         end;

        //         RecInvoiceEntry."Error Code" := '0';
        //         RecInvoiceEntry."Error Description" := Cadena;
        //         RecInvoiceEntry."Codigo Hash" := CodigoHash;
        //         RecInvoiceEntry."Elec. Document Status" := EstadoWs::Enviado;
        //         RecInvoiceEntry.Modify();

        //         Message('Documento enviado');
        //         exit;
        //     end;
        // end;


    End;


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
        FileName := 'respuesta.xml';
        DownloadFromStream(InStr, 'XML FILE', '', '', FileName);

    end;

    local procedure ValidateActiveEInvoice()
    var
        CompInfo: Record "Company Information";
        LbErrorCompany: Label 'El módulo de factura electrónica no está habilitado';
    begin
        CompInfo.Reset();
        CompInfo.Get();
        if CompInfo.Name <> 'ALITECNO' then
            Error(LbErrorCompany);

    end;

    // procedure CodeRetentio(RecRef: RecordRef)
    // var
    //     RecRetentionHeader: Record "LOCPE_Retention Entry";
    //     Error: Label 'This Invoice was prosseces before.';
    //     FileB64: Text;

    // begin


    //     RecRef.SetTable(RecRetentionHeader);
    //     // RecRetentionHeader.CalcFields(FlagEnvio);
    //     // IF (RecRetentionHeader.FlagEnvio <> 0) THEN
    //     //     Error(Error);
    //     CreateEntryRetention(RecRef);
    //     RecRetentionHeader.FlagEnvio := 1;
    //     RecRetentionHeader.Modify();

    // end;

    // local procedure CreateEntryRetention(RecRef: RecordRef)
    // var
    //     RecRetentionHeader: Record "LOCPE_Retention Entry";
    //     Error: Label 'This Invoice was prosseced before.';
    // begin

    //     RecRef.SetTable(RecRetentionHeader);
    //     InsertEntryRetention(RecRetentionHeader);
    //     InvokeMethodRetention(3, RecRetentionHeader, 5);


    // End;

    // Local procedure InsertEntryRetention(RecRetentionHeader: Record "LOCPE_Retention Entry")
    // var
    //     RecEInvoiceEntry: Record "E-Invoice Entry";
    //     RecVendor: Record Vendor;
    //     OutStr: OutStream;
    // begin
    //     RecEInvoiceEntry.SETRANGE("Document Type", RecEInvoiceEntry."Document Type"::Retencion);
    //     RecEInvoiceEntry.SETRANGE("Document No.", RecRetentionHeader."LOCPE_Voucher No.");

    //     RecVendor.SetRange("No.", RecRetentionHeader."LOCPE_VAT Registration No.");
    //     RecVendor.FindFirst;

    //     IF RecEInvoiceEntry.FindFirst THEN BEGIN
    //         RecEInvoiceEntry."Last Date" := Today;
    //         CLEAR(RecEInvoiceEntry."File Base64");
    //         RecEInvoiceEntry."File Base64".CreateOutStream(OutStr);
    //         RecEInvoiceEntry."Error Code" := '';
    //         RecEInvoiceEntry."Error Description" := '';
    //         RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";
    //         RecEInvoiceEntry."SUNAT DocType" := '20';
    //         RecEInvoiceEntry.Modify();
    //         exit;
    //     END;

    //     RecEInvoiceEntry.RESET;
    //     RecEInvoiceEntry.INIT;
    //     RecEInvoiceEntry."Document Type" := RecEInvoiceEntry."Document Type"::Retencion;
    //     RecEInvoiceEntry."Document No." := RecRetentionHeader."LOCPE_Voucher No.";
    //     RecEInvoiceEntry."Posting Date" := Today;
    //     RecEInvoiceEntry."User ID" := UserId;
    //     RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";

    //     RecEInvoiceEntry." Posting Date Document" := RecRetentionHeader."LOCPE_Posting Date";
    //     RecEInvoiceEntry."Customer No." := RecVendor."No.";
    //     RecEInvoiceEntry."Customer Name" := RecRetentionHeader."LOCPE_Vendor Name";
    //     RecEInvoiceEntry."Custemer Name 2" := RecRetentionHeader."LOCPE_Vendor Name";

    //     // RecRetentionHeader.CalcFields(LOCPE_Amount);

    //     RecEInvoiceEntry.Amount := RecRetentionHeader.LOCPE_Amount;
    //     RecEInvoiceEntry."SUNAT DocType" := '20';

    //     RecEInvoiceEntry.INSERT;


    // end;


    // Local procedure InvokeMethodRetention(DocumentType: Integer; RecRetentionHeader: Record "LOCPE_Retention Entry"; MethodType: Option " ","Registro de Documento","Estado Documento","Descarga Documento","Actualizar Estado","Registro de Retencion") response: Text
    // var
    //     RecEInvoiceentry: Record "E-Invoice Entry";

    //     XMLDoc: XmlDocument;
    //     InStr: InStream;
    //     OutStr: OutStream;
    //     FileB64: Text;
    //     TempBlob: Codeunit "Temp Blob";
    //     XMLDocResult: XmlDocument;
    //     OutStrResult: OutStream;
    //     TempBlobResult: Codeunit "Temp Blob";
    //     InStrResult: InStream;
    //     FileNameResult: Text;

    // Begin
    //     RecEInvoiceentry.RESET;
    //     // RecEInvoiceentry.SETRANGE("Document Type", DocumentType);
    //     RecEInvoiceentry.SETRANGE("Document No.", RecRetentionHeader."LOCPE_Voucher No.");
    //     IF RecEInvoiceentry.FindFirst THEN BEGIN
    //         GetCompanyInfo();
    //         GetGeneralLedgerSetup();
    //         GetWebServiceProviderSetup();
    //         GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, MethodType);

    //         CUWebSRet.CreateWsRequestLoadsDocuments(XMLDoc, RecCompanyInfo, RecGeneralLedgerSetup, '053', RecRetentionHeader, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña");
    //         // walter

    //         response := InvokeWsRetention(XMLDoc, '', '', RecWebServicesProviderDetail.URL, '');

    //         XmlMgt.LoadXMLDocumentFromText(Response, XMLDocResult);

    //         // // DownloadXml(XMLDocResult);

    //         RecEInvoiceentry."Response Document".CreateOutStream(OutStrResult);
    //         XMLDocResult.WriteTo(OutStrResult);
    //         RecEInvoiceentry.Modify();

    //         ProcessResponseWSLoadDocumentRetention(RecEInvoiceentry);

    //     END;
    // End;

    // local procedure InvokeWsRetention(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    // var
    //     HttpClientWs: HttpClient;
    //     HttpHeadersWs: HttpHeaders;
    //     HttpRequestWs: HttpRequestMessage;
    //     HttpResponseWs: HttpResponseMessage;
    //     HttpContentWs: HttpContent;
    //     StrXmlDocWs: Text;

    // begin
    //     //DownloadXml(XmlDocWs); //TEST

    //     HttpContentWs.Clear();
    //     XmlDocWs.WriteTo(StrXmlDocWs);
    //     HttpContentWs.WriteFrom(StrXmlDocWs);

    //     HttpClientWs.Clear();
    //     //ABG FIX CLOUD >>
    //     //HttpClientWs.UseWindowsAuthentication(User, Password);
    //     //ABG FIX CLOUD <<

    //     HttpContentWs.GetHeaders(HttpHeadersWs);
    //     HttpHeadersWs.Clear();
    //     HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
    //     HttpHeadersWs.Add('SOAPAction', 'http://tci.net.pe/WS_eCica/Retencion/IServicioRetencion/RegistrarComprobanteRetencion');

    //     HttpRequestWs.Content := HttpContentWs;
    //     HttpRequestWs.SetRequestUri(UrlWs);
    //     HttpRequestWs.Method := 'POST';

    //     HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

    //     HttpResponseWs.Content.ReadAs(Response);
    // end;

    // local procedure ProcessResponseWSLoadDocumentRetention(RecInvoiceEntry: Record "E-Invoice Entry")
    // var
    //     XmlDocResult: XmlDocument;
    //     TemBlob: Codeunit "Temp Blob";
    //     InStr: InStream;
    //     XMLMgt: Codeunit "SAT XML DOM Management Ext.";
    //     XMLNameSpaceMgt: XmlNamespaceManager;
    //     RootElement: XmlElement;
    //     XMLCurrNode: XmlNode;
    //     XMLElementResponse: XmlElement;
    //     ResultCode: Text;
    //     ResulObs: Text;
    //     Estado: Text;
    //     Cadena: Text;
    //     CodigoHash: Text;
    //     EstadoWs: Enum "Estado Documento";
    // Begin
    //     RecInvoiceEntry.CalcFields("Response Document");
    //     RecInvoiceEntry."Response Document".CreateInStream(InStr);
    //     XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
    //     XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

    //     XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');

    //     XmlDocResult.GetRoot(RootElement);

    //     if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarComprobanteRetencionResponse"]/*[local-name()="RegistrarComprobanteRetencionResult"]/*[local-name()="at_NivelResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //         XMLElementResponse := XMLCurrNode.AsXmlElement();
    //         Estado := XMLElementResponse.InnerText;
    //     end Else begin
    //         Estado := '';
    //     end;

    //     if (Estado = 'false') then begin
    //         if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarComprobanteRetencionResponse"]/*[local-name()="RegistrarComprobanteRetencionResult"]/*[local-name()="at_MensajeResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //             XMLElementResponse := XMLCurrNode.AsXmlElement();
    //             Cadena := XMLElementResponse.InnerText;
    //             Message(Cadena);
    //             RecInvoiceEntry."Response Observations" := Cadena;
    //             RecInvoiceEntry."Elec. Document Status" := RecInvoiceEntry."Elec. Document Status"::Enviado;
    //             RecInvoiceEntry.Modify();

    //             exit;
    //         end;
    //     end
    //     else begin
    //         if (Estado = 'true') then begin
    //             if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarComprobanteRetencionResponse"]/*[local-name()="RegistrarComprobanteRetencionResult"]/*[local-name()="at_MensajeResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //                 XMLElementResponse := XMLCurrNode.AsXmlElement();
    //                 Cadena := XMLElementResponse.InnerText;
    //             end Else begin
    //                 Cadena := '';
    //             end;
    //             if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarComprobanteRetencionResponse"]/*[local-name()="RegistrarComprobanteRetencionResult"]/*[local-name()="at_CodigoHash"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //                 XMLElementResponse := XMLCurrNode.AsXmlElement();
    //                 CodigoHash := XMLElementResponse.InnerText;
    //             end Else begin
    //                 CodigoHash := '';
    //             end;

    //             RecInvoiceEntry."Error Code" := '0';
    //             RecInvoiceEntry."Error Description" := Cadena;
    //             RecInvoiceEntry."Codigo Hash" := CodigoHash;
    //             RecInvoiceEntry."Elec. Document Status" := EstadoWs::Enviado;
    //             RecInvoiceEntry.Modify();

    //             Message('Documento enviado');
    //             exit;
    //         end;
    //     end;


    // End;

    procedure CodeBaja(RecRef: RecordRef)
    var
        RecSalesInvoiceHeader: Record "Sales Invoice Header";
        RecSalesCRHeader: Record "Sales Cr.Memo Header";
        Error: Label 'No se puede enviar La documento de baja por que se encuentra otorgado';
        ErrorCM: Label 'Este no es un documento de baja';
        FileB64: Text;

    begin
        //ValidateActiveEInvoice();

        case RecRef.Number of
            Database::"Sales Cr.Memo Header":
                Begin
                    RecRef.SetTable(RecSalesCRHeader);
                    if CopyStr(RecSalesCRHeader."No.", 1, 2) <> 'AN' then begin
                        Error(ErrorCM);
                    end;

                    RecSalesInvoiceHeader.Reset();
                    RecSalesInvoiceHeader.SetRange("No.", RecSalesCRHeader."Applies-to Doc. No.");
                    RecSalesInvoiceHeader.SetRange(Processed, true);
                    RecSalesInvoiceHeader.SetRange("Document Date", Today);

                    if (RecSalesInvoiceHeader.FindSet()) then begin
                        CreateEntryEInvoiceBaja(RecRef);
                        RecSalesInvoiceHeader.Processed := True;
                    end
                    else begin
                        Error(Error);
                    end;
                End;
        end;
    end;

    local procedure CreateEntryEInvoiceBaja(RecRef: RecordRef)
    var
        RecSalesCRHeader: Record "Sales Cr.Memo Header";
        Error: Label 'This Invoice was prosseced before.';
    begin
        case RecRef.Number of

            Database::"Sales Cr.Memo Header":
                Begin
                    RecRef.SetTable(RecSalesCRHeader);
                    InsertEntryBaja(RecSalesCRHeader);
                    InvokeMethodBaja(3, RecSalesCRHeader, 1);
                End;
        end;
    End;

    Local procedure InsertEntryBaja(RecSalesCrMemoHeader: Record "Sales Cr.Memo Header")
    var
        RecEInvoiceEntry: Record "E-Invoice Entry";
        OutStr: OutStream;
    begin

        RecEInvoiceEntry.SETRANGE("Document Type", RecEInvoiceEntry."Document Type"::Baja);
        RecEInvoiceEntry.SETRANGE("Document No.", RecSalesCrMemoHeader."No.");

        IF RecEInvoiceEntry.FindFirst THEN BEGIN
            RecEInvoiceEntry."Last Date" := Today;
            CLEAR(RecEInvoiceEntry."File Base64");
            RecEInvoiceEntry."File Base64".CreateOutStream(OutStr);
            RecEInvoiceEntry."Error Code" := '';
            RecEInvoiceEntry."Error Description" := '';
            RecEInvoiceEntry."SUNAT DocType" := RecSalesCrMemoHeader."LOCPE_Doc. Type SUNAT";
            RecEInvoiceEntry.Modify();
            exit;
        END;

        RecEInvoiceEntry.RESET;
        RecEInvoiceEntry.INIT;
        RecEInvoiceEntry."Document Type" := RecEInvoiceEntry."Document Type"::Baja;
        RecEInvoiceEntry."Document No." := RecSalesCrMemoHeader."No.";
        RecEInvoiceEntry."Posting Date" := Today;
        RecEInvoiceEntry."User ID" := UserId;
        RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";

        RecEInvoiceEntry." Posting Date Document" := RecSalesCrMemoHeader."Posting Date";
        RecEInvoiceEntry."Customer No." := RecSalesCrMemoHeader."Bill-to Customer No.";
        RecEInvoiceEntry."Customer Name" := RecSalesCrMemoHeader."Bill-to Name";
        RecEInvoiceEntry."Custemer Name 2" := RecSalesCrMemoHeader."Bill-to Name 2";

        RecSalesCrMemoHeader.CalcFields("Amount Including VAT");

        RecEInvoiceEntry.Amount := RecSalesCrMemoHeader."Amount Including VAT";
        RecEInvoiceEntry."SUNAT DocType" := RecSalesCrMemoHeader."LOCPE_Doc. Type SUNAT";

        RecEInvoiceEntry.INSERT;
    End;

    Local procedure InvokeMethodBaja(DocumentType: Integer; RecSalesInvoiceHeaderNC: Record "Sales Cr.Memo Header"; MethodType: Option " ","Registro de Documento","Estado Documento","Descarga Documento","Actualizar Estado") response: Text
    var
        RecEInvoiceentry: Record "E-Invoice Entry";

        XMLDoc: XmlDocument;
        InStr: InStream;
        OutStr: OutStream;
        FileB64: Text;
        TempBlob: Codeunit "Temp Blob";
        XMLDocResult: XmlDocument;
        OutStrResult: OutStream;
        TempBlobResult: Codeunit "Temp Blob";
        InStrResult: InStream;
        FileNameResult: Text;

    Begin
        RecEInvoiceentry.RESET;
        RecEInvoiceentry.SETRANGE("Document Type", DocumentType);
        RecEInvoiceentry.SETRANGE("Document No.", RecSalesInvoiceHeaderNC."No.");
        IF RecEInvoiceentry.FindFirst THEN BEGIN

            GetCompanyInfo();
            GetGeneralLedgerSetup();
            GetWebServiceProviderSetup();

            GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, MethodType);
            CUWebS.CreateWsRequestLoadsDocumentsBaja(XMLDoc, RecCompanyInfo, RecGeneralLedgerSetup, '053', RecSalesInvoiceHeaderNC, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña");

            response := InvokeBaja(XMLDoc, '', '', RecWebServicesProviderDetail.URL, '');

            XmlMgt.LoadXMLDocumentFromText(Response, XMLDocResult);

            // DownloadXml(XMLDocResult);

            RecEInvoiceentry."Response Document".CreateOutStream(OutStrResult);
            XMLDocResult.WriteTo(OutStrResult);
            RecEInvoiceentry.Modify();

            ProcessResponseWSLoadDocumentBaja(RecEInvoiceentry);

        END;
    End;

    local procedure InvokeBaja(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
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
        HttpHeadersWs.Add('SOAPAction', 'http://tempuri.org/IService/RegistrarComunicacionBaja');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure ProcessResponseWSLoadDocumentBaja(RecInvoiceEntry: Record "E-Invoice Entry")
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
        ResulObs: Text;
        Estado: Text;
        Cadena: Text;
        CodigoHash: Text;
        EstadoWs: Enum "Estado Documento";
        CodigoResultado: Text;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');

        XmlDocResult.GetRoot(RootElement);

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarComunicacionBajaResponse"]/*[local-name()="RegistrarComunicacionBajaResult"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            CodigoResultado := XMLElementResponse.InnerText;
        end Else begin
            Estado := 'false';
        end;

        if (Estado = 'false') then begin
            if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarComunicacionBajaResponse"]/*[local-name()="ListaError"]', XMLNameSpaceMgt, XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                Cadena := XMLElementResponse.InnerText;
                Message(Cadena);
                RecInvoiceEntry."Response Observations" := Cadena;
                RecInvoiceEntry."Elec. Document Status" := RecInvoiceEntry."Elec. Document Status"::Enviado;
                RecInvoiceEntry.Modify();

                exit;
            end;
        end
        else begin


            RecInvoiceEntry."Error Code" := '0';
            RecInvoiceEntry."Error Description" := Cadena;
            RecInvoiceEntry."Elec. Document Status" := EstadoWs::Enviado;
            RecInvoiceEntry.Modify();

            Message('Documento enviado');
            exit;

        end;


    End;

    // procedure CodeRetentioBaja(RecRef: RecordRef)
    // var
    //     RecRetentionHeader: Record "LOCPE_Retention Entry";
    //     Error: Label 'This Invoice was prosseces before.';
    //     FileB64: Text;

    // begin


    //     RecRef.SetTable(RecRetentionHeader);
    //     CreateEntryRetentionBaja(RecRef);

    // end;

    // local procedure CreateEntryRetentionBaja(RecRef: RecordRef)
    // var
    //     RecRetentionHeader: Record "LOCPE_Retention Entry";
    //     Error: Label 'This Invoice was prosseced before.';
    // begin

    //     RecRef.SetTable(RecRetentionHeader);
    //     InsertEntryRetentionBaja(RecRetentionHeader);
    //     InvokeMethodRetentionBaja(3, RecRetentionHeader, 6);
    // End;

    // Local procedure InsertEntryRetentionBaja(RecRetentionHeader: Record "LOCPE_Retention Entry")
    // var
    //     RecEInvoiceEntry: Record "E-Invoice Entry";
    //     RecVendor: Record Vendor;
    //     OutStr: OutStream;
    // begin
    //     RecEInvoiceEntry.SETRANGE("Document Type", RecEInvoiceEntry."Document Type"::Retencion);
    //     RecEInvoiceEntry.SETRANGE("Document No.", RecRetentionHeader."LOCPE_Voucher No.");

    //     RecVendor.SetRange("No.", RecRetentionHeader."LOCPE_VAT Registration No.");
    //     RecVendor.FindFirst;

    //     IF RecEInvoiceEntry.FindFirst THEN BEGIN
    //         RecEInvoiceEntry."Last Date" := Today;
    //         CLEAR(RecEInvoiceEntry."File Base64");
    //         RecEInvoiceEntry."File Base64".CreateOutStream(OutStr);
    //         RecEInvoiceEntry."Error Code" := '';
    //         RecEInvoiceEntry."Error Description" := '';
    //         RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";
    //         RecEInvoiceEntry."SUNAT DocType" := '20';
    //         RecEInvoiceEntry.Modify();
    //         exit;
    //     END;

    //     RecEInvoiceEntry.RESET;
    //     RecEInvoiceEntry.INIT;
    //     RecEInvoiceEntry."Document Type" := RecEInvoiceEntry."Document Type"::Retencion;
    //     RecEInvoiceEntry."Document No." := RecRetentionHeader."LOCPE_Voucher No.";
    //     RecEInvoiceEntry."Posting Date" := Today;
    //     RecEInvoiceEntry."User ID" := UserId;
    //     RecEInvoiceEntry."Elec. Document Status" := RecEInvoiceEntry."Elec. Document Status"::" ";

    //     RecEInvoiceEntry." Posting Date Document" := RecRetentionHeader."LOCPE_Posting Date";
    //     RecEInvoiceEntry."Customer No." := RecVendor."No.";
    //     RecEInvoiceEntry."Customer Name" := RecRetentionHeader."LOCPE_Vendor Name";
    //     RecEInvoiceEntry."Custemer Name 2" := RecRetentionHeader."LOCPE_Vendor Name";

    //     // RecRetentionHeader.CalcFields(LOCPE_Amount);

    //     RecEInvoiceEntry.Amount := RecRetentionHeader.LOCPE_Amount;
    //     RecEInvoiceEntry."SUNAT DocType" := '20';

    //     RecEInvoiceEntry.INSERT;


    // end;

    // Local procedure InvokeMethodRetentionBaja(DocumentType: Integer; RecRetentionHeader: Record "LOCPE_Retention Entry"; MethodType: Option " ","Registro de Documento","Estado Documento","Descarga Documento","Actualizar Estado","Registro de Retencion","Reversion de Retencion") response: Text
    // var
    //     RecEInvoiceentry: Record "E-Invoice Entry";

    //     XMLDoc: XmlDocument;
    //     InStr: InStream;
    //     OutStr: OutStream;
    //     FileB64: Text;
    //     TempBlob: Codeunit "Temp Blob";
    //     XMLDocResult: XmlDocument;
    //     OutStrResult: OutStream;
    //     TempBlobResult: Codeunit "Temp Blob";
    //     InStrResult: InStream;
    //     FileNameResult: Text;

    // Begin
    //     RecEInvoiceentry.RESET;
    //     // RecEInvoiceentry.SETRANGE("Document Type", DocumentType);
    //     RecEInvoiceentry.SETRANGE("Document No.", RecRetentionHeader."LOCPE_Voucher No.");
    //     IF RecEInvoiceentry.FindFirst THEN BEGIN
    //         GetCompanyInfo();
    //         GetGeneralLedgerSetup();
    //         GetWebServiceProviderSetup();
    //         GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, MethodType);

    //         CUWebSRet.CreateWsRequestLoadsDocumentsBaja(XMLDoc, RecCompanyInfo, RecGeneralLedgerSetup, '053', RecRetentionHeader, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña");
    //         //walter

    //         response := InvokeWsRetentionBaja(XMLDoc, '', '', RecWebServicesProviderDetail.URL, '');

    //         XmlMgt.LoadXMLDocumentFromText(Response, XMLDocResult);

    //         // // DownloadXml(XMLDocResult);

    //         RecEInvoiceentry."Response Document".CreateOutStream(OutStrResult);
    //         XMLDocResult.WriteTo(OutStrResult);
    //         RecEInvoiceentry.Modify();

    //         ProcessResponseWSLoadDocumentRetentionBaja(RecEInvoiceentry);

    //     END;
    // End;

    // local procedure InvokeWsRetentionBaja(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    // var
    //     HttpClientWs: HttpClient;
    //     HttpHeadersWs: HttpHeaders;
    //     HttpRequestWs: HttpRequestMessage;
    //     HttpResponseWs: HttpResponseMessage;
    //     HttpContentWs: HttpContent;
    //     StrXmlDocWs: Text;

    // begin
    //     //DownloadXml(XmlDocWs); //TEST

    //     HttpContentWs.Clear();
    //     XmlDocWs.WriteTo(StrXmlDocWs);
    //     HttpContentWs.WriteFrom(StrXmlDocWs);

    //     HttpClientWs.Clear();
    //     //ABG FIX CLOUD >>
    //     //HttpClientWs.UseWindowsAuthentication(User, Password);
    //     //ABG FIX CLOUD <<

    //     HttpContentWs.GetHeaders(HttpHeadersWs);
    //     HttpHeadersWs.Clear();
    //     HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
    //     HttpHeadersWs.Add('SOAPAction', 'http://tci.net.pe/WS_eCica/Reversiones/IServicioReversiones/RegistrarResumenReversion');

    //     HttpRequestWs.Content := HttpContentWs;
    //     HttpRequestWs.SetRequestUri(UrlWs);
    //     HttpRequestWs.Method := 'POST';

    //     HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

    //     HttpResponseWs.Content.ReadAs(Response);
    // end;

    // local procedure ProcessResponseWSLoadDocumentRetentionBaja(RecInvoiceEntry: Record "E-Invoice Entry")
    // var
    //     XmlDocResult: XmlDocument;
    //     TemBlob: Codeunit "Temp Blob";
    //     InStr: InStream;
    //     XMLMgt: Codeunit "SAT XML DOM Management Ext.";
    //     XMLNameSpaceMgt: XmlNamespaceManager;
    //     RootElement: XmlElement;
    //     XMLCurrNode: XmlNode;
    //     XMLElementResponse: XmlElement;
    //     ResultCode: Text;
    //     ResulObs: Text;
    //     Estado: Text;
    //     Cadena: Text;
    //     CodigoHash: Text;
    //     EstadoWs: Enum "Estado Documento";
    // Begin
    //     RecInvoiceEntry.CalcFields("Response Document");
    //     RecInvoiceEntry."Response Document".CreateInStream(InStr);
    //     XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
    //     XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

    //     XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');

    //     XmlDocResult.GetRoot(RootElement);

    //     if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarResumenReversionResponse"]/*[local-name()="RegistrarResumenReversionResult"]/*[local-name()="at_NivelResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //         XMLElementResponse := XMLCurrNode.AsXmlElement();
    //         Estado := XMLElementResponse.InnerText;
    //     end Else begin
    //         Estado := '';
    //     end;

    //     if (Estado = 'false') then begin
    //         if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarResumenReversionResponse"]/*[local-name()="RegistrarResumenReversionResult"]/*[local-name()="at_MensajeResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //             XMLElementResponse := XMLCurrNode.AsXmlElement();
    //             Cadena := XMLElementResponse.InnerText;
    //             Message(Cadena);
    //             RecInvoiceEntry."Response Observations" := Cadena;
    //             RecInvoiceEntry."Elec. Document Status" := RecInvoiceEntry."Elec. Document Status"::Enviado;
    //             RecInvoiceEntry.Modify();

    //             exit;
    //         end;
    //     end
    //     else begin
    //         if (Estado = 'true') then begin
    //             if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarResumenReversionResponse"]/*[local-name()="RegistrarResumenReversionResult"]/*[local-name()="at_MensajeResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //                 XMLElementResponse := XMLCurrNode.AsXmlElement();
    //                 Cadena := XMLElementResponse.InnerText;
    //             end Else begin
    //                 Cadena := '';
    //             end;
    //             if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="RegistrarResumenReversionResponse"]/*[local-name()="RegistrarResumenReversionResult"]/*[local-name()="at_CodigoHash"]', XMLNameSpaceMgt, XMLCurrNode) then begin
    //                 XMLElementResponse := XMLCurrNode.AsXmlElement();
    //                 CodigoHash := XMLElementResponse.InnerText;
    //             end Else begin
    //                 CodigoHash := '';
    //             end;

    //             RecInvoiceEntry."Error Code" := '0';
    //             RecInvoiceEntry."Error Description" := Cadena;
    //             RecInvoiceEntry."Codigo Hash" := CodigoHash;
    //             RecInvoiceEntry."Elec. Document Status" := EstadoWs::Enviado;
    //             RecInvoiceEntry.Modify();

    //             Message('Reversion de documento enviado');
    //             exit;
    //         end;
    //     end;


    // End;


}