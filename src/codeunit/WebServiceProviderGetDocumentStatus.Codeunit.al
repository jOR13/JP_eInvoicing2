codeunit 50564 "WS Prov Get Document Status"
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

        Response: Text;
        OutStrResponse: OutStream;

        RecSalesInvoiceHeader: Record "Sales Invoice Header";
    Begin
        //Company Validate
        // ValidateActiveEInvoice();
        //Company Validate

        RecEInviceEntry.Reset;
        RecEInviceEntry.SetRange("Elec. Document Status", RecEInviceEntry."Elec. Document Status"::Enviado);
        IF OpcType = '01' THEN
            RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Factura)
        Else
            RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::"Nota de credito");
        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetWebServiceProviderSetup();
                GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, 2);

                RecSalesInvoiceHeader.get(RecEInviceEntry."Document No.");
                WebServiceProviderMgt.CreateWsRequestGetDocumentsState(XMLDocWs, RecCompanyInfo, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecSalesInvoiceHeader);

                Response := InvokeWs(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '2');
                CLEAR(RecEInviceEntry."Response Document");
                REsponse := ReplaceSpecialCharacters(Response);
                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse);
                OutStrResponse.WriteText(Response);
                RecEInviceEntry.Modify(TRUE);
                ProcessResponseWSGetDoumentState(RecEInviceEntry);


            Until RecEInviceEntry.Next = 0;
        END;
    End;

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

    local procedure InvokeWs(var XmlDocWs: XmlDocument; User: Text; Password: Text; UrlWs: Text; Method: Text) Response: Text
    var
        HttpClientWs: HttpClient;
        HttpHeadersWs: HttpHeaders;
        HttpRequestWs: HttpRequestMessage;
        HttpResponseWs: HttpResponseMessage;
        HttpContentWs: HttpContent;
        StrXmlDocWs: Text;

    begin
        // DownloadXml(XmlDocWs); //TEST

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
        // HttpHeadersWs.Add('SOAPAction', 'http://tempuri.org/IService/ConsultarRespuestaComprobante');
        HttpHeadersWs.Add('SOAPAction', '');

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

    local procedure ProcessResponseWSGetDoumentState(var RecInvoiceEntry: Record "E-Invoice Entry")
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
        TEST: Text;
        TipoDoc: Text;
        Serie: Text;
        Numero: Text;
        EstadoWs: Enum "Estado Documento";
        Confirmar: Codeunit WSProvDownloadEInvoice;
        Numerox: Integer;
        XmlDocCdata: XmlDocument;
        Correlativo: Text;
        ResultDescription: Text;
        rucEmisor: Text;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('SOAP-ENV', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('ns2', 'http://com.conastec.sfe/ws/schema/sfe');

        XmlDocResult.GetRoot(RootElement);

        if RootElement.SelectSingleNode('//SOAP-ENV:Envelope/SOAP-ENV:Body/ns2:consultarEstadoComprobanteResponse/ns2:data', XMLNameSpaceMgt, XMLCurrNode) then begin

            XMLElementResponse := XMLCurrNode.AsXmlElement();
            XmlMgt.LoadXMLDocumentFromText(XMLElementResponse.InnerText, XmlDocCdata);

            if XmlDocCdata.SelectSingleNode('//consultarEstadoComprobanteRespuesta/listaComprobantes/comprobante/codigoEstado', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                ResultCode := XMLElementResponse.InnerText;
            end Else begin
                ResultCode := '';
            end;

            if XmlDocCdata.SelectSingleNode('//consultarEstadoComprobanteRespuesta/listaComprobantes/comprobante/correlativo', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                Correlativo := XMLElementResponse.InnerText;
            end Else begin
                Correlativo := '';
            end;

            if XmlDocCdata.SelectSingleNode('//consultarEstadoComprobanteRespuesta/listaComprobantes/comprobante/descripcionEstado', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                ResultDescription := XMLElementResponse.InnerText;
            end Else begin
                ResultDescription := '';
            end;

            if XmlDocCdata.SelectSingleNode('//consultarEstadoComprobanteRespuesta/listaComprobantes/comprobante/observaciones', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                ResulObs := XMLElementResponse.InnerText;
            end Else
                ResulObs := '';

            if XmlDocCdata.SelectSingleNode('//consultarEstadoComprobanteRespuesta/listaComprobantes/comprobante/rucEmisor', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                rucEmisor := XMLElementResponse.InnerText;
            end Else
                rucEmisor := '';

            if XmlDocCdata.SelectSingleNode('//consultarEstadoComprobanteRespuesta/listaComprobantes/comprobante/serie', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                Serie := XMLElementResponse.InnerText;
            end Else
                Serie := '';


            if XmlDocCdata.SelectSingleNode('//consultarEstadoComprobanteRespuesta/listaComprobantes/comprobante/tipoDocumento', XMLCurrNode) then begin
                XMLElementResponse := XMLCurrNode.AsXmlElement();
                TipoDoc := XMLElementResponse.InnerText;
            end Else
                TipoDoc := '';


            /*
            1 Por Enviar
            2 Enviado
            3 Aceptado EBIS -
            4 Rechazado EBIS
            5 Aceptado SUNAT -
            6 Aceptado SUNAT con obs -
            7 Rechazado SUNAT
            8 Para corregir
            9 En proceso de baja
            10 Baja aceptada
            */

            if (ResultCode = '3') or (ResultCode = '5') or (ResultCode = '6') then begin
                RecInvoiceEntry."Response Code" := ResultCode;
                RecInvoiceEntry."Response Web Service" := ResultDescription;
                RecInvoiceEntry."Response Observations" := ResulObs;

                RecInvoiceEntry."Elec. Document Status" := EstadoWs::Procesado;
                RecInvoiceEntry.Modify();
            end else begin
                RecInvoiceEntry."Error Code" := ResultCode;
                RecInvoiceEntry."Error Description" := ResulObs;

            end;


            //TODO Descarga de documento
            // if (Serie <> '') then begin
            //     evaluate(Numerox, Numero);

            //     if (RecInvoiceEntry."Document Type" = RecInvoiceEntry."Document Type"::Factura) then begin
            //         Confirmar.CodeConfirmacion('01', Serie, Numerox);
            //     end
            //     else begin
            //         Confirmar.CodeConfirmacion('02', Serie, Numerox);

            //     end;

            // end;
        end;

    End;

    local procedure ReplaceSpecialCharacters(XmlString: text): Text
    begin
        exit(ConvertStr(XmlString, 'ÁÉÍÓÚáéíóúÑñ˜&ÿ', 'AEIOUaeiouNn   '));
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

    procedure CodeRetention()
    var
        XMLDocWs: XmlDocument;

        Response: Text;
        OutStrResponse: OutStream;
    Begin
        //Company Validate
        // ValidateActiveEInvoice();
        //Company Validate

        RecEInviceEntry.Reset;
        RecEInviceEntry.SetRange("Elec. Document Status", RecEInviceEntry."Elec. Document Status"::Enviado);

        RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Retencion);

        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetWebServiceProviderSetup();
                GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, 5);
                WebServiceProviderMgt.CreateWsRequestGetDocumentsStateRetention(XMLDocWs, RecCompanyInfo, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña");
                Response := InvokeWsRet(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '2');

                CLEAR(RecEInviceEntry."Response Document");

                REsponse := ReplaceSpecialCharacters(Response);

                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse);

                OutStrResponse.WriteText(Response);

                RecEInviceEntry.Modify(TRUE);

                ProcessResponseWSGetDoumentStateRet(RecEInviceEntry);


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
        // DownloadXml(XmlDocWs); //TEST

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
        HttpHeadersWs.Add('SOAPAction', 'http://tci.net.pe/WS_eCica/Retencion/IServicioRetencion/ConsultarRespuestaRetencion');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure ProcessResponseWSGetDoumentStateRet(var RecInvoiceEntry: Record "E-Invoice Entry")
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
        TEST: Text;
        Codigorespuesta: Text;
        Serie: Text;
        Numero: Text;
        EstadoWs: Enum "Estado Documento";
        Confirmar: Codeunit WSProvDownloadEInvoice;
        Numerox: Integer;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('a', 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConsultarRespuestaComprobante');

        XmlDocResult.GetRoot(RootElement);
        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaRetencionResponse"]/*[local-name()="ConsultarRespuestaRetencionResult"]/*[local-name()="at_NivelResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            ResultCode := XMLElementResponse.InnerText;
        end Else
            ResultCode := '';


        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaRetencionResponse"]/*[local-name()="ConsultarRespuestaRetencionResult"]/*[local-name()="l_ResultadoRespuestaComprobante"]/*[local-name()="en_ResultadoRespuestaComprobante"]/*[local-name()="at_Serie"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            Serie := XMLElementResponse.InnerText;
        end Else
            Serie := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaRetencionResponse"]/*[local-name()="ConsultarRespuestaRetencionResult"]/*[local-name()="l_ResultadoRespuestaComprobante"]/*[local-name()="en_ResultadoRespuestaComprobante"]/*[local-name()="at_Numero"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            Numero := XMLElementResponse.InnerText;
        end Else
            Numero := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaRetencionResponse"]/*[local-name()="ConsultarRespuestaRetencionResult"]/*[local-name()="l_ResultadoRespuestaComprobante"]/*[local-name()="en_ResultadoRespuestaComprobante"]/*[local-name()="ent_RespuestaComprobante"]/*[local-name()="at_CodigoRespuesta"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            Codigorespuesta := XMLElementResponse.InnerText;
        end Else
            Codigorespuesta := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaRetencionResponse"]/*[local-name()="ConsultarRespuestaRetencionResult"]/*[local-name()="l_ResultadoRespuestaComprobante"]/*[local-name()="en_ResultadoRespuestaComprobante"]/*[local-name()="ent_RespuestaComprobante"]/*[local-name()="at_Descripcion"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            ResulObs := XMLElementResponse.InnerText;
        end Else
            ResulObs := '';

        if ResultCode = '1' then begin
            RecInvoiceEntry."Response Code" := ResultCode;
            RecInvoiceEntry."Response Web Service" := ResulObs;

            RecInvoiceEntry."Elec. Document Status" := EstadoWs::Procesado;
            RecInvoiceEntry.Modify();
        end
        else begin
            RecInvoiceEntry."Error Code" := ResultCode;
            RecInvoiceEntry."Error Description" := ResulObs;

        end;


        if (Serie <> '') then begin
            evaluate(Numerox, Numero);
            Confirmar.CodeConfirmacionRetention(Serie, Numero, Codigorespuesta);

        end;

    End;

    procedure CodeBaja()
    var
        XMLDocWs: XmlDocument;

        Response: Text;
        OutStrResponse: OutStream;
    Begin
        //Company Validate
        // ValidateActiveEInvoice();
        //Company Validate

        RecEInviceEntry.Reset;
        RecEInviceEntry.SetRange("Elec. Document Status", RecEInviceEntry."Elec. Document Status"::Enviado);

        RecEInviceEntry.SetRange("Document Type", RecEInviceEntry."Document Type"::Baja);

        IF RecEInviceEntry.FINDSET THEN BEGIN
            repeat
                GetCompanyInfo();
                GetGeneralLedgerSetup();
                GetWebServiceProviderSetup();
                GetWebServiceProviderMethodWS(RecWebServiceProvider.Codigo, 2);
                WebServiceProviderMgt.CreateWsRequestGetDocumentsStateBaja(XMLDocWs, RecCompanyInfo, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña");
                Response := InvokeWsBaja(XMLDocWs, RecWebServiceProvider.Usuario, RecWebServiceProvider."Contraseña", RecWebServicesProviderDetail.URL, '2');

                CLEAR(RecEInviceEntry."Response Document");

                REsponse := ReplaceSpecialCharacters(Response);

                RecEInviceEntry."Response Document".CreateOutStream(OutStrResponse);

                OutStrResponse.WriteText(Response);

                RecEInviceEntry.Modify(TRUE);

                ProcessResponseWSGetDoumentStateBaja(RecEInviceEntry);


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
        HttpContentWs.Clear();
        XmlDocWs.WriteTo(StrXmlDocWs);
        HttpContentWs.WriteFrom(StrXmlDocWs);

        HttpClientWs.Clear();

        HttpContentWs.GetHeaders(HttpHeadersWs);
        HttpHeadersWs.Clear();
        HttpHeadersWs.Add('Content-type', 'text/xml;charset=UTF-8');
        HttpHeadersWs.Add('SOAPAction', 'http://tempuri.org/IService/ConsultarRespuestaResumen');

        HttpRequestWs.Content := HttpContentWs;
        HttpRequestWs.SetRequestUri(UrlWs);
        HttpRequestWs.Method := 'POST';

        HttpClientWs.Send(HttpRequestWs, HttpResponseWs);

        HttpResponseWs.Content.ReadAs(Response);
    end;

    local procedure ProcessResponseWSGetDoumentStateBaja(var RecInvoiceEntry: Record "E-Invoice Entry")
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
        TEST: Text;
        Codigorespuesta: Text;
        Serie: Text;
        Numero: Text;
        EstadoWs: Enum "Estado Documento";
        Confirmar: Codeunit WSProvDownloadEInvoice;
        Numerox: Integer;
        NombreResumen: Text;
        IdResumenCliente: Text;
        TipoResumen: Text;
    Begin
        RecInvoiceEntry.CalcFields("Response Document");
        RecInvoiceEntry."Response Document".CreateInStream(InStr);
        XMLMgt.LoadXMLDocumentFromInStream(InStr, XmlDocResult);
        XMLNameSpaceMgt.NameTable(XmlDocResult.NameTable);

        XMLNameSpaceMgt.AddNamespace('s', 'http://schemas.xmlsoap.org/soap/envelope/');
        XMLNameSpaceMgt.AddNamespace('a', 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConsultarRespuestaComprobante');

        XmlDocResult.GetRoot(RootElement);
        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaResumenResponse"]/*[local-name()="ConsultarRespuestaResumenResult"]/*[local-name()="CodigoResultado"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            ResultCode := XMLElementResponse.InnerText;
        end Else
            ResultCode := '';


        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaResumenResponse"]/*[local-name()="ConsultarRespuestaResumenResult"]/*[local-name()="ResumenRespuesta"]/*[local-name()="ENResumenRespuesta"]/*[local-name()="CodigoRespuesta"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            CodigoRespuesta := XMLElementResponse.InnerText;
        end Else
            CodigoRespuesta := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaResumenResponse"]/*[local-name()="ConsultarRespuestaResumenResult"]/*[local-name()="ResumenRespuesta"]/*[local-name()="ENResumenRespuesta"]/*[local-name()="IdResumenCliente"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            IdResumenCliente := XMLElementResponse.InnerText;
        end Else
            IdResumenCliente := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaResumenResponse"]/*[local-name()="ConsultarRespuestaResumenResult"]/*[local-name()="ResumenRespuesta"]/*[local-name()="ENResumenRespuesta"]/*[local-name()="NombreResumen"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            NombreResumen := XMLElementResponse.InnerText;
        end Else
            NombreResumen := '';

        if RootElement.SelectSingleNode('//s:Envelope/s:Body/*[local-name()="ConsultarRespuestaResumenResponse"]/*[local-name()="ConsultarRespuestaResumenResult"]/*[local-name()="ResumenRespuesta"]/*[local-name()="ENResumenRespuesta"]/*[local-name()="TipoResumen"]', XMLNameSpaceMgt, XMLCurrNode) then begin
            XMLElementResponse := XMLCurrNode.AsXmlElement();
            TipoResumen := XMLElementResponse.InnerText;
        end Else
            TipoResumen := '';

        if ResultCode = '1' then begin

            RecInvoiceEntry."Elec. Document Status" := EstadoWs::Procesado;
            RecInvoiceEntry.Modify();
        end
        else begin
            RecInvoiceEntry."Error Code" := ResultCode;
            RecInvoiceEntry."Error Description" := ResulObs;

        end;


        if (NombreResumen <> '') then begin
            Confirmar.CodeConfirmacionBaja(NombreResumen, TipoResumen, IdResumenCliente);

        end;

    End;
}