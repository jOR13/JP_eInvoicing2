codeunit 50563 "WS Prov Mgt."
{
    Permissions = tabledata "Sales Invoice Header" = rm,
                    tabledata "Sales Cr.Memo Header" = rm;
    trigger OnRun()
    begin
        //CreateWsRequestLoadsDocuments();


    end;

    var
        XmlMgt: Codeunit "SAT XML DOM Management Ext.";



    /// <summary>
    /// Arma el XML a tratar
    /// </summary>
    /// <param name="XmlDocWs"> XML armado que se retornará </param>
    /// <param name="CompanyInfo"></param>
    /// <param name="RecGLSetup"></param>
    /// <param name="DocType"></param>
    /// <param name="RecSalesInvoiceHeader"></param>
    /// <param name="UserName"></param>
    /// <param name="Password"></param>
    procedure CreateWsRequestLoadsDocuments(
        var XmlDocWs: XmlDocument; CompanyInfo: Record "Company Information"; RecGLSetup: Record "General Ledger Setup";
        DocType: Code[20]; RecSalesInvoiceHeader: Record "Sales Invoice Header"; UserName: Text[50]; Password: Text[50])
    var
        RecCurrency: Record Currency;
        RecGeneralLEdgerSetup: Record "General Ledger Setup";
        RecCompanyInformation: Record "Company Information";
        RecPostCode: Record "Post Code";
        RecCountry: Record "Country/Region";
        RecCustomer: Record Customer;
        RecPostCodeCust: Record "Post Code";
        RecSalesperson: Record "Salesperson/Purchaser";
        RecsalesReferencia: Record "Sales Invoice Header";
        RecCountryCust: Record "Country/Region";
        RecPostCodeShip: Record "Post Code";
        RecCountryShip: Record "Country/Region";
        RecShippingAgent: Record "Shipping Agent";
        RecSalesInvoiceLine: Record "Sales Invoice Line";
        RecSalesInvoiceLineRecargo: Record "Sales Invoice Line";
        RecItem: Record Item;
        RecPaymentTerms: Record "Payment Terms";
        RecVatPostingGroup: Record "VAT Product Posting Group";
        RecVATProductPostingGrup: Record "VAT Product Posting Group";
        VATProdPostGr: Record "VAT Product Posting Group";
        RecUnitOfMesure: Record "Unit of Measure";
        Almacen: Record Location;
        RecBanco: Record "Bank Account";
        ValorCuenta: Text;
        ValorCuentaCCI: Text;
        LeerBlod: Codeunit "Type Helper";
        ResultadoLinea: Text;
        PosSalto: Integer;
        PosInicial: Integer;
        PosFinal: Integer;

        DecPriceWithOutVAT: Decimal;
        DecPriceWithVAT: Decimal;
        TotalIGV: Decimal;
        TotalRecargo: Decimal;
        TotalIGVFinal: Decimal;
        TotalBase: Decimal;
        TotalBaseDes: Decimal;
        TotalExonerado: Decimal;
        TotalExportacion: Decimal;
        TotalGratuito: Decimal;
        TotalImpGratuito: Decimal;
        TotalGravado: Decimal;
        TotalInafecto: Decimal;
        TotalIgvBase: Decimal;
        TotalImporte: Decimal;
        TotalBolsa: Decimal;
        TotalImpuestoMixto: Decimal;
        TotalBaseMixto: Decimal;
        TotalBaseAnticipo: Decimal;
        TotalIgvBaseAnticipo: Decimal;
        TotalPrecioVenta: Text;
        TotalValorVenta: Text;

        //Var Banderas
        LlaveGratuiInafecto: Integer;
        LlaveGratuito: Integer;
        LlaveGravada: Integer;
        LlaveExportacion: Integer;
        LlaveAnticipo: Integer;
        LlaveAnticipoCabecera: Integer;

        ContadorLinea: Integer;

        _ImporteIgv: Decimal;
        ProvinceCode: Code[30];
        DepartmentCode: Code[30];
        DistrictCode: Code[30];

        AmountPrePayment: Decimal;
        SalesInvHeadePrepagoL: Record "Sales Invoice Header";
        SalesInvHeadePrepagoL2: Record "Sales Shipment Header";
        RecGuia: Record "Sales Shipment Header";
        recSeie: Record "No. Series";

        MetodoPago: Record "Payment Method";
        recAnticipo: Record DetalleAnticiposAplicados;

        MyInStream: InStream;
        ResultGlosa: Text;

        TextoAlmacen: Text;
        TextoFlagFreeDoc: Text;
        TextoFlagDetraccion: Text;
        TextoFlagFormaPago: Text;
        TextoFlagFormaPagoSUNAT: Text;

        CodigoUN: Text;
        DesTributo: Text;

        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        XmlStrCData: Text;
        // XmlStrMethodBody: Text;
        XmlStrInvoiceLines: Text;
        CRLF: Text[2];

        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceSFE: Label 'http://com.conastec.sfe/ws/schema/sfe', Locked = true;


        mcodigoSUNAT: Text;
        mimporteValorVentaItem: Text;
        mCodigoTipoPrecio: Text;
        munidadMedida: Text;
        mvalorVentaUnitario: Text;
        mValorVentaUnitarioIncIgv: Text;
        mImporteExplicito: Text;
        mMontoBase: Text;
        mTasaAplicada: Text;
        mTotal: Text;
        mMontoDescuento: Text;
        mMontoBaseDescuento: Text;
        mPorcentajeDescuento: Text;
        mImpuestoTotal: Text;
        mCantidadBolsa: Text;
        mValorImpuestoBolsa: Text;
        mValorImpuestoUnitarioBolsa: Text;

    begin

        #region Carga de Datos
        Clear(ProvinceCode);
        Clear(DepartmentCode);
        Clear(DistrictCode);

        //Obtengo los datos del Cliente
        RecCustomer.GET(RecSalesInvoiceHeader."Bill-to Customer No.");

        //Obtengo las lineas del detalle de venta para un determinado InvoiceHeader
        RecSalesInvoiceLine.RESET;
        RecSalesInvoiceLine.SETRANGE("Document No.", RecSalesInvoiceHeader."No.");

        //Compruebo si tiene vendedor(?)
        if RecSalesInvoiceHeader."Salesperson Code" <> '' then begin
            RecSalesperson.GET(RecSalesInvoiceHeader."Salesperson Code");
        end;

        //Obtengo datos de compañia
        RecCompanyInformation.GET();

        //Reseteo documento de refencia
        RecsalesReferencia.Reset();

        //Compruebo si no tiene documento de refencia, para nota de crédito
        IF NOT RecsalesReferencia.GET(RecSalesInvoiceHeader."LOCPE_No. FR Relation ND") THEN
            CLEAR(RecsalesReferencia);

        //Valores para salto de línea
        CRLF[1] := 13;
        CRLF[2] := 10;
        #endregion

        XmlStr := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sfe="http://com.conastec.sfe/ws/schema/sfe">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.AddElement(XMLCurrNodeWs, 'enviarComprobanteRequest', '', LbNameSpaceSFE, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;


        XmlStrCData := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + CRLF;
        XmlStrCData := XmlStrCData +
        '<enviarComprobante> ' + CRLF +
        '   <header>' + CRLF +
        '       <fechaTransaccion>2021-12-09 12:35:59</fechaTransaccion>' + CRLF +
        '       <idEmisor>20489332621</idEmisor>' + CRLF +
        '       <token>iATOgjFSbBWwPIUHhZ1B8ou2mF4=</token>' + CRLF +
        '       <transaccion>enviarComprobanteRequest</transaccion>' + CRLF +
        '   </header>' + CRLF;

        #region comprobanteElectrónico
        XmlStrCData := XmlStrCData +
        '   <comprobanteElectronico>' + CRLF;

        RecSalesInvoiceLineRecargo.RESET;

        RecSalesInvoiceLineRecargo.SETRANGE("Document No.", RecSalesInvoiceHeader."No.");
        IF RecSalesInvoiceLineRecargo.FINDFIRST THEN BEGIN
            REPEAT
                if (RecSalesInvoiceLineRecargo."VAT Prod. Posting Group" = 'RECARGO') then begin
                    TotalRecargo := TotalRecargo + RecSalesInvoiceLineRecargo."Amount Including VAT";
                end;
            UNTIL RecSalesInvoiceLineRecargo.NEXT = 0;
        END;

        // if (TotalRecargo <> 0) then begin
        //     XmlMgt.AddElement(XMLCurrNodeWs, 'CargoNoAfecto', FORMAT(TotalRecargo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
        //     XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        // end;

        LlaveGratuiInafecto := 0;
        LlaveGratuito := 0;
        LlaveGravada := 0;
        LlaveExportacion := 0;
        LlaveAnticipo := 0;
        TotalBaseAnticipo := 0;
        TotalIgvBaseAnticipo := 0;
        LlaveAnticipoCabecera := 0;
        TotalRecargo := 0;
        ContadorLinea := 0;

        TotalPrecioVenta := '0.00';
        TotalValorVenta := '0.00';
        recAnticipo.Reset();
        recAnticipo.SetRange(FacturaOriginal, RecSalesInvoiceHeader."Pre-Assigned No.");

        if (recAnticipo.FindFirst()) then begin
            LlaveAnticipoCabecera := 1;
        end else begin
            recAnticipo.Reset();
            recAnticipo.SetRange(FacturaOriginal, RecSalesInvoiceHeader."Order No.");

            if (recAnticipo.FindFirst()) then begin
                LlaveAnticipoCabecera := 1;
            end;
        end;

        TextoAlmacen := '';

        if (RecSalesInvoiceHeader."LOCPE_Free Document" = true) then begin
            TextoFlagFreeDoc := 'true';
        end else begin
            TextoFlagFreeDoc := 'false';
        end;

        if (RecSalesInvoiceHeader."LOCPE_Sales Detraccion" = true) then begin
            TextoFlagDetraccion := 'S';
        end else begin
            TextoFlagDetraccion := 'N';
        end;

        if (RecSalesInvoiceHeader."Payment Terms Code" = '000') then begin
            TextoFlagFormaPago := 'CON';
            TextoFlagFormaPagoSUNAT := 'Contado';
        end else begin
            TextoFlagFormaPago := 'CRE';
            TextoFlagFormaPagoSUNAT := 'Credito';
        end;

        #region InvoiceLines
        IF RecSalesInvoiceLine.FINDFIRST THEN BEGIN
            REPEAT
                if (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'RECARGO') then begin
                    TotalRecargo := TotalRecargo + RecSalesInvoiceLine."Amount Including VAT";
                end else begin
                    ContadorLinea += 1;
                    //Forma anterior para anticipo, porque se ingresaba como negativo
                    if (RecSalesInvoiceLine."Line Amount" < 0) then begin
                        LlaveAnticipo += 1;
                        TotalBaseAnticipo += (RecSalesInvoiceLine."Line Amount" * -1);
                        TotalIgvBaseAnticipo += ((RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01)) * -1);
                    end;

                    if RecSalesInvoiceLine."Location Code" = '' then begin
                        TextoAlmacen := RecSalesInvoiceLine."Location Code";
                    end;

                    if (RecSalesInvoiceLine."No." <> '') AND (RecSalesInvoiceLine."Line Amount" > 0) then begin
                        if (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'GRAT-INAFE') then begin
                            LlaveGratuiInafecto += 1;
                        end;
                        if (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'IGV') then begin
                            LlaveGravada += 1;
                        end;
                        if (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'TGRAUITO') then begin
                            LlaveGratuito += 1;
                        end;
                        if (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BONIFICA') then begin
                            LlaveGratuito += 1;
                        end;
                        if (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'EXPORT') then begin
                            LlaveExportacion += 1;
                        end;

                        RecVatPostingGroup.GET(RecSalesInvoiceLine."VAT Prod. Posting Group");
                        RecVATProductPostingGrup.GET(RecSalesInvoiceLine."VAT Prod. Posting Group");

                        if RecSalesInvoiceHeader."Prices Including VAT" then begin
                            if RecSalesInvoiceLine."VAT %" <> 0 then
                                DecPriceWithOutVAT := (RecSalesInvoiceLine."Unit Price" / ((RecSalesInvoiceLine."VAT %" / 100) + 1))
                            else
                                DecPriceWithOutVAT := RecSalesInvoiceLine."Unit Price"
                        end
                        else begin
                            DecPriceWithOutVAT := RecSalesInvoiceLine."Unit Price";
                            DecPriceWithVAT := RecSalesInvoiceLine."Amount Including VAT" / RecSalesInvoiceLine.Quantity;//  RecSalesInvoiceLine."Unit Price" * ((RecSalesInvoiceLine."VAT %" / 100) + 1);
                        end;

                        #region calculo variables
                        mcodigoSUNAT := '';
                        mimporteValorVentaItem := '';
                        mCodigoTipoPrecio := '';
                        munidadMedida := '';
                        mvalorVentaUnitario := '';
                        mValorVentaUnitarioIncIgv := '';
                        mImporteExplicito := '';
                        mMontoBase := '';
                        mTasaAplicada := '';
                        mTotal := '';
                        mMontoDescuento := '';
                        mPorcentajeDescuento := '';
                        mMontoBaseDescuento := '';
                        mImpuestoTotal := '';
                        // XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteDetalle', '', LbNameSpaceLib, XMLNewChildWs);
                        //     XMLCurrNodeWs := XMLNewChildWs;

                        //     XmlMgt.AddElement(XMLCurrNodeWs, 'Cantidad', FORMAT(RecSalesInvoiceLine.Quantity, 0, '<Precision,5:5><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                        //     XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        // XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', ReplaceString(RecSalesInvoiceLine."No.", '-', ''), LbNameSpaceLib, XMLNewChildWs);
                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


                        IF RecItem.GET(RecSalesInvoiceLine."No.") THEN begin
                            mcodigoSUNAT := RecItem."LOCPE_Item SUNAT";
                        end else begin
                            //TODO preguntar el porqué de esta lógica
                            mcodigoSUNAT := '31201501';
                        end;

                        VATProdPostGr.Reset();
                        VATProdPostGr.Get(RecSalesInvoiceLine."VAT Prod. Posting Group");

                        if (VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion]) then begin
                            mCodigoTipoPrecio := '02';
                        end else begin
                            mCodigoTipoPrecio := '01';
                        end;


                        // XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteDetalleImpuestos', '', LbNameSpaceLib, XMLNewChildWs);
                        // XMLCurrNodeWs := XMLNewChildWs;

                        // XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteDetalleImpuestos', '', LbNameSpaceLib, XMLNewChildWs);
                        // XMLCurrNodeWs := XMLNewChildWs;


                        // if (RecVATProductPostingGrup."LOCPE_VAT Code SUNAT" <> '9999') then begin
                        //     XmlMgt.AddElement(XMLCurrNodeWs, 'AfectacionIGV', RecVatPostingGroup."LOCPE_VAT Type SUNAT", LbNameSpaceLib, XMLNewChildWs);
                        //     XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        // end;

                        // XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoTributo', RecVatPostingGroup."LOCPE_VAT Code SUNAT", LbNameSpaceLib, XMLNewChildWs);
                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        case RecVatPostingGroup."LOCPE_VAT Code SUNAT" of
                            '1000':
                                begin
                                    CodigoUN := 'VAT';
                                    DesTributo := 'IGV';


                                    TotalBaseMixto += Round(RecSalesInvoiceLine."Line Amount", 0.01);
                                    //El resultado es el mismo, acumula el monto de impuesto que se va aplicando a cada linea
                                    if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                                        TotalImpuestoMixto += Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01);
                                    end
                                    else begin
                                        TotalImpuestoMixto += RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount";
                                    end;
                                end;
                            '1016':
                                begin
                                    CodigoUN := 'VAT';
                                    DesTributo := 'IVAP';
                                end;
                            '2000':
                                begin
                                    CodigoUN := 'EXC';
                                    DesTributo := 'ISC';
                                end;
                            '9995':
                                begin
                                    CodigoUN := 'FRE';
                                    DesTributo := 'EXP';
                                end;
                            '9996':
                                begin
                                    CodigoUN := 'FRE';
                                    DesTributo := 'GRA';
                                end;
                            '9997':
                                begin
                                    CodigoUN := 'VAT';
                                    DesTributo := 'EXO';
                                end;
                            '9998':
                                begin
                                    CodigoUN := 'FRE';
                                    DesTributo := 'INA';
                                end;
                            '9999':
                                begin
                                    CodigoUN := 'OTH';
                                    DesTributo := 'OTROS';
                                end;
                        end;

                        // XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoUN', CodigoUN, LbNameSpaceLib, XMLNewChildWs);
                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        // XmlMgt.AddElement(XMLCurrNodeWs, 'DesTributo', DesTributo, LbNameSpaceLib, XMLNewChildWs);
                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                            TotalIGV += Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01);
                            TotalIGVFinal += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                        end else begin
                            TotalIGV += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                        end;

                        if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::Exportacion, VATProdPostGr."Type VAT"::Inafecto, VATProdPostGr."Type VAT"::Exonerado] then begin
                            mImporteExplicito := '0';

                            // XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteTributo', '0', LbNameSpaceLib, XMLNewChildWs);
                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end else begin
                            if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                                _ImporteIgv := Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01);
                            end else begin
                                _ImporteIgv := RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount";
                            end;
                            mImporteExplicito := FORMAT(_ImporteIgv, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');

                            // //XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteTributo', FORMAT(((RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount")) - RecSalesInvoiceLine."Line Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            // XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteTributo', FORMAT(_ImporteIgv, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;

                        TotalBaseDes += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);

                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::General) then begin
                            TotalBase += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;

                        if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::General, VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion] then begin
                            if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                mMontoBase := FORMAT(Round(RecSalesInvoiceLine."Line Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end else begin
                                mMontoBase := FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end;

                        end else begin
                            mMontoBase := FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                        end;

                        if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::General, VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion] then begin
                            mTasaAplicada := FORMAT(RecSalesInvoiceLine."VAT %", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                        end else begin
                            mTasaAplicada := FORMAT(0.0, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                        end;

                        if (VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion]) then begin
                            TotalGratuito += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;
                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::Inafecto) then begin
                            TotalInafecto += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                            TotalInafecto := TotalInafecto - TotalBaseAnticipo;
                        end;
                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::Exportacion) then begin
                            TotalExportacion += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;
                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::Exonerado) then begin
                            TotalExonerado += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;


                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteDetalleImpuestos
                        // XMLNewChildWs := XMLCurrNodeWs;

                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteDetalleImpuestos
                        // XMLNewChildWs := XMLCurrNodeWs;

                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteDetalle
                        // XMLNewChildWs := XMLCurrNodeWs;

                        // XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', RecSalesInvoiceLine.Description, LbNameSpaceLib, XMLNewChildWs);
                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BOLSA') THEN begin

                            // XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoItem', '', LbNameSpaceLib, XMLNewChildWs);
                            // XMLCurrNodeWs := XMLNewChildWs;
                            // XmlMgt.AddElement(XMLCurrNodeWs, 'BolsaPlasticoItem', '', LbNameSpaceLib, XMLNewChildWs);
                            // XMLCurrNodeWs := XMLNewChildWs;

                            TotalBolsa += RecSalesInvoiceLine.Quantity * DecPriceWithOutVAT;
                            // XmlMgt.AddElement(XMLCurrNodeWs, 'Cantidad', FORMAT(RecSalesInvoiceLine.Quantity, 0, '<Precision,5:5><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            mCantidadBolsa := FORMAT(RecSalesInvoiceLine.Quantity, 0, '<Precision,5:5><Integer><Decimals><Comma,.>');
                            // XmlMgt.AddElement(XMLCurrNodeWs, 'ValorImpuesto', FORMAT(TotalBolsa, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            mValorImpuestoBolsa := FORMAT(TotalBolsa, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');

                            // XmlMgt.AddElement(XMLCurrNodeWs, 'ValorImpuestoUnitario', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            mValorImpuestoUnitarioBolsa := FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');


                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ImpuestoItem
                            // XMLNewChildWs := XMLCurrNodeWs;
                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ImpuestoItem
                            // XMLNewChildWs := XMLCurrNodeWs;

                        end;

                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //BolsaPlasticoItem
                        // XMLNewChildWs := XMLCurrNodeWs;
                        //factura o boleta
                        if (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '03') then begin
                            IF RecSalesInvoiceLine."Line Discount Amount" > 0 THEN begin
                                // XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoCargoDetalle', '', LbNameSpaceLib, XMLNewChildWs);
                                // XMLCurrNodeWs := XMLNewChildWs;

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoDetalle', '', LbNameSpaceLib, XMLNewChildWs);
                                // XMLCurrNodeWs := XMLNewChildWs;

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoAplicado', '00', LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '0', LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(RecSalesInvoiceLine."Line Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                mMontoDescuento := FORMAT(RecSalesInvoiceLine."Line Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(RecSalesInvoiceLine."Line Amount" + RecSalesInvoiceLine."Line Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                mMontoBaseDescuento := FORMAT(RecSalesInvoiceLine."Line Amount" + RecSalesInvoiceLine."Line Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'Porcentaje', FORMAT(RecSalesInvoiceLine."Line Discount %", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                mPorcentajeDescuento := FORMAT(RecSalesInvoiceLine."Line Discount %", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');


                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoDetalle
                                // XMLNewChildWs := XMLCurrNodeWs;
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoDetalle
                                // XMLNewChildWs := XMLCurrNodeWs;

                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteDetalle
                                // XMLNewChildWs := XMLCurrNodeWs;


                            end;
                        end;

                        if VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::General then begin
                            IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BOLSA') THEN begin
                                // XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', FORMAT((RecSalesInvoiceLine.Quantity * DecPriceWithOutVAT) + RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                mImpuestoTotal := FORMAT((RecSalesInvoiceLine.Quantity * DecPriceWithOutVAT) + RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end else begin
                                if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                                    // XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', FORMAT(Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    mImpuestoTotal := FORMAT(Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                end else begin
                                    // XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', FORMAT(RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    mImpuestoTotal := FORMAT(RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                end;

                            end;
                        end else begin
                            // XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', '0.00', LbNameSpaceLib, XMLNewChildWs);
                            // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            mImpuestoTotal := '0.00';
                        end;
                        //MultiDescripcion
                        // XmlMgt.AddElement(XMLCurrNodeWs, 'Item', FORMAT(RecSalesInvoiceLine."Line No." / 10000), LbNameSpaceLib, XMLNewChildWs);
                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


                        // XmlMgt.AddElement(XMLCurrNodeWs, 'Nota', RecSalesInvoiceLine."No.", LbNameSpaceLib, XMLNewChildWs);
                        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        if (VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion]) then begin
                            mimporteValorVentaItem := '0.00';
                        end ELSE begin
                            if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                                mimporteValorVentaItem := FORMAT(TotalImporte + TotalRecargo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end else begin
                                mimporteValorVentaItem := FORMAT(DecPriceWithVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end;
                        end;



                        if VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::General then begin
                            mTotal := FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                        end else begin
                            if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::Inafecto, VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Exportacion, VATProdPostGr."Type VAT"::Exonerado, VATProdPostGr."Type VAT"::Bonificacion] then
                                mTotal := FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                        end;

                        if RecUnitOfMesure.Get(RecSalesInvoiceLine."Unit of Measure Code") then begin
                            munidadMedida := RecUnitOfMesure."LOCPE_Unit of Measure SUNAT";
                        end else begin
                            if (RecSalesInvoiceLine."Unit of Measure Code" <> '') then begin
                                munidadMedida := RecSalesInvoiceLine."Unit of Measure Code";
                            end else begin
                                munidadMedida := 'NIU';
                            end;
                        end;

                        case VATProdPostGr."Type VAT" of
                            VATProdPostGr."Type VAT"::General:
                                begin
                                    mvalorVentaUnitario := FORMAT(round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', '');

                                    TotalGravado := TotalBase;
                                    TotalIgvBase += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                                end;
                            VATProdPostGr."Type VAT"::Exportacion:
                                begin
                                    mvalorVentaUnitario := FORMAT(Round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', '');
                                    //                                TotalExportacion += TotalBase;

                                end;

                            VATProdPostGr."Type VAT"::Inafecto:
                                begin
                                    mvalorVentaUnitario := FORMAT(Round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', '');
                                    //                              TotalInafecto += TotalBase;
                                end;
                            VATProdPostGr."Type VAT"::"Transferencia Gratuita":
                                begin
                                    mvalorVentaUnitario := '0.00';
                                    //                                TotalGratuito += TotalBase;
                                    TotalImpGratuito += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                                end;
                            VATProdPostGr."Type VAT"::Bonificacion:
                                begin
                                    mvalorVentaUnitario := '0.00';
                                    //                                TotalGratuito += TotalBase;
                                    TotalImpGratuito += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                                end;
                            VATProdPostGr."Type VAT"::Exonerado:
                                begin
                                    mvalorVentaUnitario := FORMAT(Round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', '')
                                    //                              TotalExonerado += TotalBase;
                                end;
                        end;

                        case VATProdPostGr."Type VAT" of
                            VATProdPostGr."Type VAT"::General:
                                begin
                                    IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BOLSA') THEN begin
                                        mValorVentaUnitarioIncIgv := FORMAT(_ImporteIgv + RecSalesInvoiceLine."Amount Including VAT", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                        //mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT + DecPriceWithVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                    end else begin
                                        if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                                            if (LlaveAnticipoCabecera > 0) then begin
                                                mValorVentaUnitarioIncIgv := FORMAT(_ImporteIgv + RecSalesInvoiceLine."Amount Including VAT", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                                //mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT + DecPriceWithVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                            end else begin
                                                mValorVentaUnitarioIncIgv := FORMAT(_ImporteIgv + RecSalesInvoiceLine."Amount Including VAT", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                                //mValorVentaUnitarioIncIgv := FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                            end;
                                        end else begin
                                            mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT + DecPriceWithVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                        end;
                                    end;
                                end;
                            VATProdPostGr."Type VAT"::Exportacion:
                                begin
                                    if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                        mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT - (RecSalesInvoiceLine."Line Discount Amount" / RecSalesInvoiceLine.Quantity), 0, '<Precision,2:2><Integer><Decimals><Comma,.>')
                                    end else begin
                                        mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                    end;
                                end;
                            VATProdPostGr."Type VAT"::Inafecto:
                                begin
                                    mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                end;
                            VATProdPostGr."Type VAT"::"Transferencia Gratuita":
                                begin
                                    mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                end;
                            VATProdPostGr."Type VAT"::Bonificacion:
                                begin
                                    mValorVentaUnitarioIncIgv := FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                end;
                        end;
                        #endregion



                        //Parseo de variables a InvoiceLines
                        XmlStrInvoiceLines := XmlStrInvoiceLines +
                        '   <itemsComprobantePagoElectronicoVenta>' + CRLF;

                        XmlStrInvoiceLines := XmlStrInvoiceLines +
                        '       <cantidad>' + FORMAT(RecSalesInvoiceLine.Quantity, 0, '<Precision,3:3><Integer><Decimals><Comma,.>') + '</cantidad>' + CRLF +
                        //
                        '       <cargoNoAfectaIGV>0.00</cargoNoAfectaIGV>' + CRLF +
                        '       <cargoNoAfectaIGVFactor>0</cargoNoAfectaIGVFactor>' + CRLF +

                        '       <codigoProducto>' + ReplaceString(RecSalesInvoiceLine."No.", '-', '') + '</codigoProducto>' + CRLF +
                        '       <codigoSUNAT>' + mcodigoSUNAT + '</codigoSUNAT>' + CRLF +
                        '       <descripcionProducto>' + RecSalesInvoiceLine.Description + '</descripcionProducto>' + CRLF +

                        //TODO descuentoAfectaIGV help
                        '       <descuentoAfectaIGV>0.00</descuentoAfectaIGV>' + CRLF +

                        '       <detalleProducto/>' + CRLF +
                        '       <gratuito>' + TextoFlagFreeDoc + '</gratuito>' + CRLF +
                        '       <importeTotal>' + FORMAT(TotalBaseDes + _ImporteIgv, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</importeTotal>' + CRLF +
                        '       <importeValorVentaItem>' + mMontoBase + '</importeValorVentaItem>' + CRLF +

                        '       <impuestosUnitarios>' + CRLF +
                        '       	<codigoImpuestoUnitario>' + RecVatPostingGroup."LOCPE_VAT Code SUNAT" + '</codigoImpuestoUnitario>' + CRLF;
                        if (RecVATProductPostingGrup."LOCPE_VAT Code SUNAT" <> '9999') then begin
                            XmlStrInvoiceLines := XmlStrInvoiceLines +
                            '          <codigoTipoAfectacionIgv>' + RecVatPostingGroup."LOCPE_VAT Type SUNAT" + '</codigoTipoAfectacionIgv>' + CRLF;
                        end;

                        XmlStrInvoiceLines := XmlStrInvoiceLines +
                        '       	<montoBaseImpuesto>' + mMontoBase + '</montoBaseImpuesto>' + CRLF +
                        '       	<montoSubTotalImpuestoUnitario>' + mImporteExplicito + '</montoSubTotalImpuestoUnitario>' + CRLF +

                        '       	<montoTotalImpuestoUnitario>' + mImporteExplicito + '</montoTotalImpuestoUnitario>' + CRLF +
                        '       </impuestosUnitarios>' + CRLF +

                        //TODO indicadorDescuento duda
                        '       <indicadorDescuento>true</indicadorDescuento>' + CRLF +

                        '       <montoDescuento>' + mMontoDescuento + '</montoDescuento>' + CRLF +
                        '       <numeroOrden>' + Format(ContadorLinea) + '</numeroOrden>' + CRLF +


                        //TODO precioReferencia  duda
                        '       <precioReferencia>false</precioReferencia>' + CRLF +

                        '       <preciosUnitarios>' + CRLF +
                        '       	<codigoTipoPrecio>' + mCodigoTipoPrecio + '</codigoTipoPrecio>' + CRLF +
                        '       	<montoPrecio>' + FORMAT(TotalBaseDes + _ImporteIgv, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</montoPrecio>' + CRLF +
                        '       </preciosUnitarios>' + CRLF +
                        '       <unidadMedida>' + munidadMedida + '</unidadMedida>' + CRLF +
                        '       <valorVentaUnitario>' + mMontoBase + '</valorVentaUnitario>' + CRLF;
                        // <valorVentaUnitario>' + mvalorVentaUnitario + '</valorVentaUnitario>' + CRLF;




                        XmlStrInvoiceLines := XmlStrInvoiceLines +
                        '   </itemsComprobantePagoElectronicoVenta>' + CRLF;
                    end;
                end;

            UNTIL RecSalesInvoiceLINE.NEXT = 0;
        END;
        #endregion

        #region Previo a Invoice Lines

        if LlaveAnticipo > 0 then begin
            XmlStrCData := XmlStrCData +
        '		<anticipo>true</anticipo>' + CRLF;
        end else begin
            XmlStrCData := XmlStrCData +
        '		<anticipo>false</anticipo>' + CRLF;
        end;

        #region detraccion factura-boleta
        // if (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '03') then begin
        //     if (RecSalesInvoiceHeader."LOCPE_Sales Detraccion" = true) then begin


        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'Detraccion', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'ENDetraccion', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'BienesServicios', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'ENBienesServicios', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '3000', LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', RecSalesInvoiceHeader.LOCPE_SalesDetractServiceType, LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENBienesServicios
        //         // XMLNewChildWs := XMLCurrNodeWs;

        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENBienesServicios
        //         // XMLNewChildWs := XMLCurrNodeWs;

        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //BienesServicios
        //         // XMLNewChildWs := XMLCurrNodeWs;

        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'ENMonto', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '2003', LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', FORMAT(RecSalesInvoiceHeader."LOCPE_SalesDetract(LCY)Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENMonto
        //         // XMLNewChildWs := XMLCurrNodeWs;
        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENMonto
        //         // XMLNewChildWs := XMLCurrNodeWs;
        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Monto
        //         // XMLNewChildWs := XMLCurrNodeWs;

        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'NumeroCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;
        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'ENNumeroCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '3001', LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        //         XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoFormaPago', '001', LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', '00000522910', LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENNumeroCuenta
        //         // XMLNewChildWs := XMLCurrNodeWs;
        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENNumeroCuenta
        //         // XMLNewChildWs := XMLCurrNodeWs;
        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //NumeroCuenta
        //         // XMLNewChildWs := XMLCurrNodeWs;

        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'Porcentaje', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;
        //         // XmlMgt.AddElement(XMLCurrNodeWs, 'ENPorcentaje', '', LbNameSpaceLib, XMLNewChildWs);
        //         // XMLCurrNodeWs := XMLNewChildWs;

        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '2003', LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        //         XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', FORMAT(RecSalesInvoiceHeader.LOCPE_SalesDetractionPercent, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
        //         XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENPorcentaje
        //         // XMLNewChildWs := XMLCurrNodeWs;
        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENPorcentaje
        //         // XMLNewChildWs := XMLCurrNodeWs;
        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Porcentaje
        //         // XMLNewChildWs := XMLCurrNodeWs;

        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDetraccion
        //         // XMLNewChildWs := XMLCurrNodeWs;
        //         // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Detraccion
        //         // XMLNewChildWs := XMLCurrNodeWs;

        //     end;
        // end;
        #endregion

        #region TotalImporte
        if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
            TotalImporte := ((TotalIGVFinal - TotalIgvBaseAnticipo) + (TotalBaseDes - TotalBaseAnticipo)) - RecSalesInvoiceHeader."Invoice Discount Value";
        end
        else begin
            TotalImporte := ((TotalIGV - TotalIgvBaseAnticipo) + (TotalBaseDes - TotalBaseAnticipo)) - RecSalesInvoiceHeader."Invoice Discount Value";
        end;

        if (TotalBolsa <> 0) then begin
            TotalImporte := TotalImporte + TotalBolsa
        end;

        IF (LlaveGravada <> 0) THEN begin
            if (LlaveGratuito <> 0) then begin
                TotalImporte := (TotalBaseMixto - TotalBaseAnticipo) + (TotalImpuestoMixto - TotalIgvBaseAnticipo);
            end;
        end
        else begin
            if (LlaveGratuiInafecto <> 0) then begin
                TotalImporte := 0;
            end;

        end;
        //
        if (RecSalesInvoiceHeader."LOCPE_Free Document" = true) then begin
            TotalImporte := 0;
        end;
        #endregion

        #region Totales
        if (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '03') then begin

            IF (LlaveGravada = 0) AND (LlaveExportacion > 0) AND (RecSalesInvoiceHeader."Invoice Discount Value" > 0) THEN begin
                TotalPrecioVenta := FORMAT(TotalExportacion + TotalIgvBaseAnticipo + TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
            end
            ELSE begin
                if LlaveAnticipoCabecera = 0 then begin
                    TotalPrecioVenta := FORMAT((TotalImporte + TotalIgvBaseAnticipo + TotalBaseAnticipo) - (TotalBaseAnticipo + TotalIgvBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                end
                else begin
                    TotalPrecioVenta := FORMAT((TotalImporte + TotalIgvBaseAnticipo + TotalBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                end;
            end;
            // if (LlaveAnticipoCabecera > 0) then begin
            //     XmlMgt.AddElement(XMLCurrNodeWs, 'TotalPrepago', FORMAT(TotalBaseAnticipo + TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            //     XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            // end;

            if (LlaveGravada <> 0) then begin
                if (LlaveGratuito <> 0) then begin
                    TotalValorVenta := FORMAT(TotalBaseMixto, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                end else begin
                    if (RecSalesInvoiceHeader."LOCPE_Free Document" = false) then begin

                        if (LlaveGratuiInafecto <> 0) then begin
                            TotalValorVenta := '0.00';
                        end else begin
                            if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                                if (LlaveAnticipo <> 0) then begin
                                    TotalValorVenta := FORMAT(TotalBase - RecSalesInvoiceHeader."Invoice Discount Value", 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                end else begin
                                    TotalValorVenta := FORMAT(TotalImporte - TotalIGVFinal, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                                end;

                            end else begin
                                TotalValorVenta := FORMAT(TotalBaseDes, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end;
                        end;

                    end else begin
                        TotalValorVenta := '0.00';
                    end;
                end;
            end else begin
                if (RecSalesInvoiceHeader."LOCPE_Free Document" = false) then begin

                    if (LlaveGratuiInafecto <> 0) then begin
                        TotalValorVenta := '0.00';
                    end else begin
                        if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                            IF (LlaveGravada = 0) AND (LlaveExportacion > 0) AND (RecSalesInvoiceHeader."Invoice Discount Value" > 0) THEN begin
                                TotalValorVenta := FORMAT(TotalExportacion, 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end else begin
                                TotalValorVenta := FORMAT(TotalImporte - TotalIGVFinal - (TotalBaseAnticipo + TotalIgvBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>')
                            end;
                        end else begin
                            IF (TotalInafecto <> 0) THEN begin
                                TotalValorVenta := FORMAT(TotalBaseDes - (TotalIgvBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end else begin
                                TotalValorVenta := FORMAT(TotalBaseDes - (TotalBaseAnticipo + TotalIgvBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>');
                            end;
                        end;
                    end;

                end else begin
                    TotalValorVenta := '0.00';
                end;
            end;
        end;
        #endregion





        #region  parseo de Variables
        XmlStrCData := XmlStrCData +
        '       <codTipoOperacion>' + RecSalesInvoiceHeader."LOCPE_Operation Type FE" + '</codTipoOperacion>' + CRLF +
        '       <codigoEmisor>' + RecCompanyInformation."VAT Registration No." + '</codigoEmisor>' + CRLF +
        '       <codigoTipoDocumentoIdentificacionAdquiriente>' + RecCustomer.LOCPE_DocTypeIdentitySUNAT + '</codigoTipoDocumentoIdentificacionAdquiriente>' + CRLF +
        '       <codigoTipoDocumentoIdentificacionEmisor>' + RecCompanyInformation."LOCPE_Doc. Type SUNAT" + '</codigoTipoDocumentoIdentificacionEmisor>' + CRLF;
        if (RecSalesInvoiceHeader."Currency Code" = '') then begin
            XmlStrCData := XmlStrCData +
        '       <codigoTipoMoneda>' + 'PEN' + '</codigoTipoMoneda>' + CRLF;
        end else begin
            XmlStrCData := XmlStrCData +
        '       <codigoTipoMoneda>' + RecSalesInvoiceHeader."Currency Code" + '</codigoTipoMoneda>' + CRLF;
        end;
        XmlStrCData := XmlStrCData +
        '       <correoElectronicoAdquiriente>' + RecCustomer."E-Mail" + '</correoElectronicoAdquiriente>' + CRLF;

        #region descuentos
        //TODO check descuentos
        if (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" = '03') then begin
            IF (LlaveExportacion > 1) THEN begin
                // XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoNoAfecto', FORMAT(RecSalesInvoiceHeader."Invoice Discount Value", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                XmlStrCData := XmlStrCData +
                '       <descuentoGlobal>' + FORMAT(RecSalesInvoiceHeader."Invoice Discount Value", 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</descuentoGlobal>' + CRLF +
                '       <totalDscNoAfecta>' + FORMAT(RecSalesInvoiceHeader."Invoice Discount Value", 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalDscNoAfecta>' + CRLF;
            end
            else begin
                // XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoGlobal', FORMAT(RecSalesInvoiceHeader."Invoice Discount Value", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlStrCData := XmlStrCData +
                '       <descuentoGlobal>' + FORMAT(RecSalesInvoiceHeader."Invoice Discount Value", 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</descuentoGlobal>' + CRLF +
                '       <totalDscNoAfecta>0.00</totalDscNoAfecta>' + CRLF;
            end;
        end;
        #endregion

        #region detalleDetraccion
        if (RecSalesInvoiceHeader."LOCPE_Sales Detraccion" = true) then begin
            XmlStrCData := XmlStrCData +
            '       <detalleDetraccion>' + CRLF +
            //TODO codigoBienOSevicio
            '	        <codigoBienOSevicio>001</codigoBienOSevicio>' + CRLF +

            '           <medioPago>001</medioPago>' + CRLF +
            '           <monto>' + FORMAT(RecSalesInvoiceHeader."LOCPE_SalesDetract(LCY)Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</monto>' + CRLF +
            '           <montoBase>' + FORMAT(TotalImporte + TotalRecargo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</montoBase>' + CRLF +
            '           <porcentaje>' + FORMAT(RecSalesInvoiceHeader.LOCPE_SalesDetractionPercent, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</porcentaje>' + CRLF +
            '       </detalleDetraccion>';
        end;
        #endregion

        #region direcciones

        RecCountryCust.GET(RecCustomer."Country/Region Code");
        DepartmentCode := CopyStr(RecPostCodeCust."LOCPE_Department", 1, 29);
        DistrictCode := CopyStr(RecPostCodeCust."LOCPE_District", 1, 29);
        ProvinceCode := CopyStr(RecPostCodeCust."LOCPE_Province", 1, 29);

        XmlStrCData := XmlStrCData +
        '       <direccionAdquiriente>' + CRLF +
        '           <codigoPais>' + RecCountryCust."LOCPE_Sunat Code" + '</codigoPais>' + CRLF +
        '           <departamento>' + DepartmentCode + '</departamento>' + CRLF +
        '           <direccionDetallada>' + RecCustomer.Address + '</direccionDetallada>' + CRLF +
        '           <distrito>' + DistrictCode + '</distrito>' + CRLF +
        '           <provincia>' + ProvinceCode + '</provincia>' + CRLF +
        '       </direccionAdquiriente>' + CRLF;


        //TODO codigoSunatAnexo Y codigoSede
        XmlStrCData := XmlStrCData +
        '       <direccionEmisor>' + CRLF +
        '           <codigoSunatAnexo>0000</codigoSunatAnexo>' + CRLF +
        '           <codigoPais>' + RecGLSetup."Codigo Pais" + '</codigoPais>' + CRLF +
        '           <departamento>' + recPostCode."LOCPE_Department" + '</departamento>' + CRLF +
        '           <direccionDetallada>' + RecCompanyInformation.Address + '</direccionDetallada>' + CRLF +
        '           <distrito>' + recPostCode.LOCPE_District + '</distrito>' + CRLF +
        '           <provincia>' + recPostCode.LOCPE_Province + '</provincia>' + CRLF +
        '       </direccionEmisor>' + CRLF;

        XmlStrCData := XmlStrCData +
        '       <direccionEntregaBienOPrestaServicio>' + CRLF +
        '           <codigoPais>' + RecSalesInvoiceHeader."Ship-to Code" + '</codigoPais>' + CRLF +
        '           <codigoSUNATAnexo>0000</codigoSUNATAnexo>' + CRLF +
        '           <codigoUbigeo>' + RecSalesInvoiceHeader."Ship-to Post Code" + '</codigoUbigeo>' + CRLF +
        '           <departamento></departamento>' + CRLF +
        '           <direccionDetallada>' + RecSalesInvoiceHeader."Ship-to Address" + '</direccionDetallada>' + CRLF +
        '           <distrito>' + RecSalesInvoiceHeader."Ship-to City" + '</distrito>' + CRLF +
        '           <provincia></provincia>' + CRLF +
        '       </direccionEntregaBienOPrestaServicio>' + CRLF;

        #endregion

        //TODO evaluar si es necesario especificar campos en estructuraVariable
        // <estructuraVariable>
        // 	<listadoDeEstructuras>
        // 		<nombre>CAJERO</nombre>
        // 		<valor>UDEMO_HOTELUNU</valor>
        // 	</listadoDeEstructuras>
        // 	<listadoDeEstructuras>
        // 		<nombre>CENTRO_COSTO</nombre>
        // 		<valor>ADMINISTRACION</valor>
        // 	</listadoDeEstructuras>
        // 	<listadoDeEstructuras>
        // 		<nombre>SEDE</nombre>
        // 		<valor>SEDE PRINCIPAL</valor>
        // 	</listadoDeEstructuras>
        // </estructuraVariable>

        XmlStrCData := XmlStrCData +
        '       <fechaEmision>' + FORMAT(RecSalesInvoiceHeader."Document Date", 0, '<Year4>-<Month,2>-<Day,2>') + '</fechaEmision>' + CRLF +
        '       <fechaVencimiento>' + FORMAT(RecSalesInvoiceHeader."Due Date", 0, '<Year4>-<Month,2>-<Day,2>') + '</fechaVencimiento>' + CRLF +
        '       <formaPago>' + TextoFlagFormaPago + '</formaPago>' + CRLF +
        '       <formaPagoSUNAT>' + CRLF +
        '          <formaPago>' + TextoFlagFormaPagoSUNAT + '</formaPago>' + CRLF +
        '       </formaPagoSUNAT>' + CRLF +
        '       <gratuito>' + TextoFlagFreeDoc + '</gratuito>' + CRLF +
        '       <horaEmision>' + FORMAT(CurrentDateTime, 0, '<Hours24,2><Filler Character,0>:<Minutes,2>:<Seconds,2>') + '</horaEmision>' + CRLF +
        '       <identificador>' + CRLF +
        '           <codigoTipoDocumento>' + RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" + '</codigoTipoDocumento>' + CRLF +
        '           <numeroCorrelativo>' + COPYSTR(RecSalesInvoiceHeader."No.", 6, 8) + '</numeroCorrelativo>' + CRLF +
        '           <numeroDocumentoIdentificacionEmisor>' + RecCompanyInformation."VAT Registration No." + '</numeroDocumentoIdentificacionEmisor>' + CRLF +
        '           <serie>' + COPYSTR(RecSalesInvoiceHeader."No.", 1, 4) + '</serie>' + CRLF +
        '           <tipoEmision>ELE</tipoEmision>' + CRLF +
        '        </identificador>' + CRLF +
        '      <importeTotal>' + FORMAT(TotalBaseDes + _ImporteIgv, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</importeTotal>' + CRLF +
        //<importeTotal>' + FORMAT(TotalImporte + TotalRecargo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</importeTotal>' + CRLF +

        '       <indicadorOperacionSujetaDetraccion>' + TextoFlagDetraccion + '</indicadorOperacionSujetaDetraccion>' + CRLF +
        '       <indicadorRetornoEstado>N</indicadorRetornoEstado>' + CRLF;
        #endregion

        //Concatena XmlStrCData con XmlStrInvoiceLines
        XmlStrCData := XmlStrCData + XmlStrInvoiceLines;



        IF RecCustomer."LOCPE_DocTypeIdentitySUNAT" = '6' THEN //RUC
        begin
            XmlStrCData := XmlStrCData +
        '       <numeroDocumentoIdentificacionAdquiriente>' + RecCustomer."VAT Registration No." + '</numeroDocumentoIdentificacionAdquiriente>' + CRLF;
        end
        ELSE begin
            XmlStrCData := XmlStrCData +
        '       <numeroDocumentoIdentificacionAdquiriente>' + RecCustomer."LOCPE_DNI/CE/Other" + '</numeroDocumentoIdentificacionAdquiriente>' + CRLF;
        end;


        XmlStrCData := XmlStrCData +
        '       <observaciones></observaciones>' + CRLF +
        '       <precioReferencial>false</precioReferencial>' + CRLF +
        #region Monto en Letras
        '       <propiedadesAdicionales>' + CRLF +
        '          <codigoPropiedadAdicional>1000</codigoPropiedadAdicional>' + CRLF;
        IF (RecSalesInvoiceHeader."LOCPE_Free Document" = false) then begin
            XmlStrCData := XmlStrCData +
            '          <descripcionPropiedadAdicional>' + DIN_FUN_CONVERTIR_NUMEROS_LETRA(TotalImporte + TotalRecargo, RecSalesInvoiceHeader."Currency Code") + '</descripcionPropiedadAdicional>' + CRLF;
        end else begin
            XmlStrCData := XmlStrCData +
            '          <descripcionPropiedadAdicional>' + DIN_FUN_CONVERTIR_NUMEROS_LETRA(0, RecSalesInvoiceHeader."Currency Code") + '</descripcionPropiedadAdicional>' + CRLF;
        end;
        XmlStrCData := XmlStrCData +
        '       </propiedadesAdicionales>' + CRLF;
        #endregion

        #region Texto Transferencia Gratuita
        IF (RecSalesInvoiceHeader."LOCPE_Free Document" = true) then begin
            XmlStrCData := XmlStrCData +
            '       <propiedadesAdicionales>' + CRLF +
            '          <codigoPropiedadAdicional>1002</codigoPropiedadAdicional>' + CRLF +
            '          <descripcionPropiedadAdicional>TRANSFERENCIA GRATUITA DE UN BIEN Y/O SERVICIO PRESTADO GRATUITAMENTE</descripcionPropiedadAdicional>' + CRLF +
            '       </propiedadesAdicionales>' + CRLF;
        end;
        #endregion

        #region Texto Detracción
        IF (RecSalesInvoiceHeader."LOCPE_Sales Detraccion" = true) then begin
            XmlStrCData := XmlStrCData +
            '       <propiedadesAdicionales>' + CRLF +
            '          <codigoPropiedadAdicional>2006</codigoPropiedadAdicional>' + CRLF +
            '          <descripcionPropiedadAdicional>Operación sujeta a detracción</descripcionPropiedadAdicional>' + CRLF +
            '       </propiedadesAdicionales>' + CRLF;
        end;
        #endregion

        XmlStrCData := XmlStrCData +
        '       <razonSocialAdquiriente>' + RecCustomer.Name + '</razonSocialAdquiriente>' + CRLF +
        '       <razonSocialEmisor>' + RecCompanyInformation.Name + '</razonSocialEmisor>' + CRLF +

        //TODO Averiguar como calcular sumatoriaOtrosCargos y Ticket
        '       <sumatoriaOtrosCargos>0.00</sumatoriaOtrosCargos>' + CRLF +
        '       <ticket>false</ticket>' + CRLF;


        #region Impuestos
        #region totalIgv
        ///TEST
        if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
            XmlStrCData := XmlStrCData +
            '       <totalIgv>' + Format(TotalIGVFinal) + '</totalIgv>' + CRLF;
        end else begin
            XmlStrCData := XmlStrCData +
            '       <totalIgv>' + Format(TotalIGV) + '</totalIgv>' + CRLF;
        end;
        ;

        #endregion

        #region totalImpuesto
        if (LlaveGravada <> 0) then begin
            if (LlaveGratuito <> 0) then begin
                XmlStrCData := XmlStrCData +
                '       <totalImpuesto>' + FORMAT(TotalImpuestoMixto - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalImpuesto>' + CRLF;
            end else begin
                if (RecSalesInvoiceHeader."LOCPE_Free Document" = false) then begin
                    if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                        XmlStrCData := XmlStrCData +
                        '       <totalImpuesto>' + FORMAT(TotalIGVFinal - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalImpuesto>' + CRLF;
                    end else begin
                        XmlStrCData := XmlStrCData +
                        '       <totalImpuesto>' + FORMAT(TotalIGV - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalImpuesto>' + CRLF;
                    end;
                end else begin
                    XmlStrCData := XmlStrCData +
                    '       <totalImpuesto>' + '0.0' + '</totalImpuesto>' + CRLF;
                end;
            end;
        end else begin
            if (RecSalesInvoiceHeader."LOCPE_Free Document" = false) then begin
                if (RecSalesInvoiceHeader."Invoice Discount Value" <> 0) then begin
                    XmlStrCData := XmlStrCData +
                    '       <totalImpuesto>' + FORMAT(TotalIGVFinal - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalImpuesto>' + CRLF;
                end else begin
                    XmlStrCData := XmlStrCData +
                    '       <totalImpuesto>' + FORMAT(TotalIGV - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalImpuesto>' + CRLF;
                end;
            end else begin
                XmlStrCData := XmlStrCData +
                    '       <totalImpuesto>' + '0.0' + '</totalImpuesto>' + CRLF;

            end;
        end;
        #endregion

        //TODO Impuestto Selectivo al consumidor

        XmlStrCData := XmlStrCData +
        '       <totalIsc>0.00</totalIsc>' + CRLF;
        #endregion


        #region Totales
        XmlStrCData := XmlStrCData +
        '       <totalOperacionExportacion>' + FORMAT(TotalExportacion, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalOperacionExportacion>' + CRLF +
        '       <totalOperacionGratuito>0.00</totalOperacionGratuito>' + CRLF +
        '       <totalPrecioVenta>' + TotalPrecioVenta + '</totalPrecioVenta>' + CRLF +
        '       <totalTributoGratuito>0.00</totalTributoGratuito>' + CRLF +
        '       <totalValorVenta>' + TotalValorVenta + '</totalValorVenta>' + CRLF +
        '       <totalValorVentaOperacionesExoneradas>' + FORMAT(TotalExonerado, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalValorVentaOperacionesExoneradas>' + CRLF +
        //TODO duda
        '       <totalValorVentaOperacionesGravadas>' + mvalorVentaUnitario + '</totalValorVentaOperacionesGravadas>' + CRLF;

        if LlaveAnticipoCabecera <> 0 then begin
            XmlStrCData := XmlStrCData +
    '       <totalValorVentaOperacionesInafectas>' + FORMAT(TotalInafecto, 0, '<Precision,2:2><Integer><Decimals><Comma,.>') + '</totalValorVentaOperacionesInafectas>' + CRLF;
        end else begin
            XmlStrCData := XmlStrCData +
        '       <totalValorVentaOperacionesInafectas>' + '0.00' + '</totalValorVentaOperacionesInafectas>' + CRLF;
        end;
        #endregion



        XmlStrCData := XmlStrCData +
        '       <usuario>' + RecSalesInvoiceHeader."User ID" + '</usuario>' + CRLF +
        //TODO averiguar casos VentaItinerante
        '       <ventaItinerante>false</ventaItinerante>' + CRLF;


        XmlStrCData := XmlStrCData +
        '   </comprobanteElectronico>' + CRLF;

        XmlStrCData := XmlStrCData +
        '</enviarComprobante>';
        #endregion

        //Establece CData
        XmlMgt.AddElementCData(XMLCurrNodeWs, 'data', XmlStrCData, LbNameSpaceSFE, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //data
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //enviarComprobanteRequest
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //body
        XMLNewChildWs := XMLCurrNodeWs;

        #endregion


        //test
        DownloadXml(XmlDocWs);

    end;


    procedure CreateWsRequestLoadsDocumentsNC(var XmlDocWs: XmlDocument; CompanyInfo: Record "Company Information"; RecGLSetup: Record "General Ledger Setup"; DocType: Code[20]; RecSalesInvoiceHeaderNC: Record "Sales Cr.Memo Header"; UserName: Text[50]; Password: Text[50])
    var
        RecCurrency: Record Currency;
        RecGeneralLEdgerSetup: Record "General Ledger Setup";
        RecCompanyInformation: Record "Company Information";
        RecPostCode: Record "Post Code";
        RecCountry: Record "Country/Region";
        RecCustomer: Record Customer;
        RecPostCodeCust: Record "Post Code";
        RecSalesperson: Record "Salesperson/Purchaser";
        RecsalesReferencia: Record "Sales Invoice Header";
        RecCountryCust: Record "Country/Region";
        RecPostCodeShip: Record "Post Code";
        RecCountryShip: Record "Country/Region";
        RecShippingAgent: Record "Shipping Agent";
        RecSalesInvoiceLine: Record "Sales Cr.Memo Line";
        RecItem: Record Item;
        RecPaymentTerms: Record "Payment Terms";
        RecVatPostingGroup: Record "VAT Product Posting Group";
        RecVATProductPostingGrup: Record "VAT Product Posting Group";
        VATProdPostGr: Record "VAT Product Posting Group";
        RecUnitOfMesure: Record "Unit of Measure";
        DecPriceWithOutVAT: Decimal;
        DecPriceWithVAT: Decimal;
        TotalIGV: Decimal;
        TotalBase: Decimal;
        TotalBaseDes: Decimal;
        TotalExonerado: Decimal;
        TotalExportacion: Decimal;
        TotalGratuito: Decimal;
        TotalImpGratuito: Decimal;
        TotalGravado: Decimal;
        TotalInafecto: Decimal;
        TotalIgvBase: Decimal;
        TotalImporte: Decimal;
        TotalBaseMixto: Decimal;
        TotalImpuestoMixto: Decimal;
        TotalIGVFinal: Decimal;
        TotalBolsa: Decimal;
        TotalDescentoNC: Decimal;
        TotalBaseAnticipo: Decimal;
        TotalIgvBaseAnticipo: Decimal;
        LlaveGratuiInafecto: Integer;
        LlaveGratuito: Integer;
        LlaveGravada: Integer;
        LlaveExportacion: Integer;
        LlaveAnticipo: Integer;
        LlaveAnticipoCabecera: Integer;

        RecSunat: Record LOCPE_Sunat;

        RecSalesInvoiceLineRecargo: Record "Sales Cr.Memo Line";
        TotalRecargo: Decimal;

        _ImporteIgv: Decimal;
        // fix space line 
        ProvinceCode: Code[30];
        DepartmentCode: Code[30];
        DistrictCode: Code[30];

        AmountPrePayment: Decimal;
        SalesInvHeadePrepagoL: Record "Sales Cr.Memo Header";
        SalesInvHeadePrepagoL2: Record "Sales Shipment Header";

        CodigoUN: Text;
        DesTributo: Text;

        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceTem: Label 'http://tempuri.org/', Locked = true;
        LbNameSpaceLib: Label 'http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion', Locked = true;
        LbNameSpaceArr: Label 'http://schemas.microsoft.com/2003/10/Serialization/Arrays', Locked = true;
        LbNameSpaceDll: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio', Locked = true;

        LbNameSpaceLoad: Label 'http://ws.seres.com/wsdl/20150301/LoadsDocuments/', Locked = true;
        LbNameSpaceWsse: label 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd', Locked = true;

    begin
        //cargar datos
        Clear(ProvinceCode);
        Clear(DepartmentCode);
        Clear(DistrictCode);

        RecCustomer.GET(RecSalesInvoiceHeaderNC."Bill-to Customer No.");
        RecSalesInvoiceLine.RESET;
        RecSalesInvoiceLine.SETRANGE("Document No.", RecSalesInvoiceHeaderNC."No.");

        RecSalesperson.RESET;
        RecSalesperson.SETRANGE(Code, RecSalesInvoiceHeaderNC."Salesperson Code");
        RecCompanyInformation.GET();

        RecsalesReferencia.Reset();
        IF NOT RecsalesReferencia.GET(RecSalesInvoiceHeaderNC."LOCPE_No. Corrected Doc. FR") THEN
            CLEAR(RecsalesReferencia);

        //Fin cargar datos
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:lib="http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays" xmlns:dll="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Registrar', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oGeneral', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Autenticacion', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Clave', Password, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', UserName, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENComprobante', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'CantidadRegistros', '1', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        RecSalesInvoiceLineRecargo.RESET;

        RecSalesInvoiceLineRecargo.SETRANGE("Document No.", RecSalesInvoiceHeaderNC."No.");
        IF RecSalesInvoiceLineRecargo.FINDFIRST THEN BEGIN
            REPEAT
                if (RecSalesInvoiceLineRecargo."VAT Prod. Posting Group" = 'RECARGO') then begin
                    TotalRecargo := TotalRecargo + RecSalesInvoiceLineRecargo."Amount Including VAT";
                end;
            UNTIL RecSalesInvoiceLineRecargo.NEXT = 0;
        END;

        if (TotalRecargo <> 0) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'CargoNoAfecto', FORMAT(TotalRecargo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        end;

        TotalRecargo := 0;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ClienteDireccion', RecCustomer.Address, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'CodMediosPago', RecSalesInvoiceHeaderNC."Payment Terms Code", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoCliente', RecSalesInvoiceHeaderNC."Bill-to Customer No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteAlias', RecSalesInvoiceHeaderNC."No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


        XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteDetalle', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        LlaveGratuiInafecto := 0;
        LlaveGratuito := 0;
        LlaveGravada := 0;
        LlaveExportacion := 0;
        LlaveAnticipo := 0;
        TotalBaseAnticipo := 0;
        TotalIgvBaseAnticipo := 0;
        LlaveAnticipoCabecera := 0;
        TotalRecargo := 0;

        if (RecSalesInvoiceHeaderNC."LOCPE_Canceled Document" = true) then begin
            LlaveAnticipoCabecera := 1;
        end;

        IF RecSalesInvoiceLine.FINDFIRST THEN BEGIN
            REPEAT
                if (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'RECARGO') then begin
                    TotalRecargo := TotalRecargo + RecSalesInvoiceLine."Amount Including VAT";
                end
                ELSE begin
                    TotalDescentoNC += RecSalesInvoiceLine."Line Discount Amount";
                    if (RecSalesInvoiceLine.Quantity < 0) then begin
                        LlaveAnticipo += 1;
                        TotalBaseAnticipo += (RecSalesInvoiceLine."Line Amount" * -1);
                        TotalIgvBaseAnticipo += ((RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01)) * -1);
                    end;
                    IF (RecSalesInvoiceLine."No." <> '') AND (RecSalesInvoiceLine.Quantity > 0) THEN BEGIN

                        IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'GRAT-INAFE') then begin
                            LlaveGratuiInafecto += 1;
                        end;
                        IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'IGV') then begin
                            LlaveGravada += 1;
                        end;
                        IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'TGRAUITO') then begin
                            LlaveGratuito += 1;
                        end;
                        IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BONIFICA') then begin
                            LlaveGratuito += 1;
                        end;
                        IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'EXPORT') then begin
                            LlaveExportacion += 1;
                        end;

                        recVatPostingGroup.GET(RecSalesInvoiceLine."VAT Prod. Posting Group");
                        RecVATProductPostingGrup.GET(RecSalesInvoiceLine."VAT Prod. Posting Group");

                        IF RecSalesInvoiceHeaderNC."Prices Including VAT" THEN begin
                            IF RecSalesInvoiceLine."VAT %" <> 0 THEN
                                DecPriceWithOutVAT := (RecSalesInvoiceLine."Unit Price" / ((RecSalesInvoiceLine."VAT %" / 100) + 1))
                            ELSE
                                DecPriceWithOutVAT := RecSalesInvoiceLine."Unit Price"
                        end
                        else begin
                            DecPriceWithOutVAT := RecSalesInvoiceLine."Unit Price";
                            DecPriceWithVAT := RecSalesInvoiceLine."Amount Including VAT" / RecSalesInvoiceLine.Quantity;//  RecSalesInvoiceLine."Unit Price" * ((RecSalesInvoiceLine."VAT %" / 100) + 1);
                        end;

                        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteDetalle', '', LbNameSpaceLib, XMLNewChildWs);
                        XMLCurrNodeWs := XMLNewChildWs;

                        XmlMgt.AddElement(XMLCurrNodeWs, 'Cantidad', FORMAT(RecSalesInvoiceLine.Quantity, 0, '<Precision,5:5><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', ReplaceString(RecSalesInvoiceLine."No.", '-', ''), LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        IF RecItem.GET(RecSalesInvoiceLine."No.") THEN begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoProductoSunat', RecItem."LOCPE_Item SUNAT", LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end
                        ELSE begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoProductoSunat', '31201501', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;

                        VATProdPostGr.Reset();
                        VATProdPostGr.Get(RecSalesInvoiceLine."VAT Prod. Posting Group");

                        IF (VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion]) then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoTipoPrecio', '02', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end
                        ELSE begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoTipoPrecio', '01', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;


                        XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteDetalleImpuestos', '', LbNameSpaceLib, XMLNewChildWs);
                        XMLCurrNodeWs := XMLNewChildWs;

                        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteDetalleImpuestos', '', LbNameSpaceLib, XMLNewChildWs);
                        XMLCurrNodeWs := XMLNewChildWs;


                        if (RecVATProductPostingGrup."LOCPE_VAT Code SUNAT" <> '9999') then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'AfectacionIGV', RecVatPostingGroup."LOCPE_VAT Type SUNAT", LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;

                        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoTributo', RecVatPostingGroup."LOCPE_VAT Code SUNAT", LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        case RecVatPostingGroup."LOCPE_VAT Code SUNAT" of
                            '1000':
                                begin
                                    CodigoUN := 'VAT';
                                    DesTributo := 'IGV';


                                    TotalBaseMixto += Round(RecSalesInvoiceLine."Line Amount", 0.01);

                                    if (RecSalesInvoiceHeaderNC."Invoice Discount Amount" <> 0) then begin
                                        TotalImpuestoMixto += Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01);
                                    end
                                    else begin
                                        TotalImpuestoMixto += RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount";
                                    end;
                                end;
                            '1016':
                                begin
                                    CodigoUN := 'VAT';
                                    DesTributo := 'IVAP';
                                end;
                            '2000':
                                begin
                                    CodigoUN := 'EXC';
                                    DesTributo := 'ISC';
                                end;
                            '9995':
                                begin
                                    CodigoUN := 'FRE';
                                    DesTributo := 'EXP';
                                end;
                            '9996':
                                begin
                                    CodigoUN := 'FRE';
                                    DesTributo := 'GRA';
                                end;
                            '9997':
                                begin
                                    CodigoUN := 'VAT';
                                    DesTributo := 'EXO';
                                end;
                            '9998':
                                begin
                                    CodigoUN := 'FRE';
                                    DesTributo := 'INA';
                                end;
                            '9999':
                                begin
                                    CodigoUN := 'OTH';
                                    DesTributo := 'OTROS';
                                end;
                        end;

                        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoUN', CodigoUN, LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        XmlMgt.AddElement(XMLCurrNodeWs, 'DesTributo', DesTributo, LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                            TotalIGV += Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01);
                            TotalIGVFinal += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                        end
                        else begin
                            TotalIGV += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                        end;
                        if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::Exportacion, VATProdPostGr."Type VAT"::Inafecto, VATProdPostGr."Type VAT"::Exonerado] then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteExplicito', '0', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                            XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteTributo', '0', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end
                        else begin
                            if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                _ImporteIgv := RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount";
                                // _ImporteIgv := Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01);
                            end
                            else begin
                                _ImporteIgv := RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount";
                            end;

                            XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteExplicito', FORMAT(_ImporteIgv, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                            //XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteTributo', FORMAT(((RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount")) - RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteTributo', FORMAT(_ImporteIgv, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;

                        TotalBaseDes += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);

                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::General) then begin
                            TotalBase += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;

                        if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::General, VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion] then begin
                            if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                // XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(Round(RecSalesInvoiceLine."Line Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end
                            else begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end;

                        end
                        else begin
                            if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end
                            else begin
                                if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end
                                else begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end;

                            end;
                        end;

                        if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::General, VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion] then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'TasaAplicada', FORMAT(RecSalesInvoiceLine."VAT %", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end
                        else begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'TasaAplicada', FORMAT(0.0, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;

                        if (VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion]) then begin
                            TotalGratuito += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;
                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::Inafecto) then begin
                            TotalInafecto += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;
                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::Exportacion) then begin
                            if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                TotalExportacion += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                            end
                            else begin
                                if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                    TotalExportacion += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.01);
                                end
                                else begin
                                    TotalExportacion += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                                end;
                            end;


                        end;
                        if (VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::Exonerado) then begin
                            TotalExonerado += Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01);
                        end;


                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteDetalleImpuestos
                        XMLNewChildWs := XMLCurrNodeWs;

                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteDetalleImpuestos
                        XMLNewChildWs := XMLCurrNodeWs;

                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteDetalle
                        XMLNewChildWs := XMLCurrNodeWs;

                        XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', RecSalesInvoiceLine.Description, LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BOLSA') THEN begin

                            XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoItem', '', LbNameSpaceLib, XMLNewChildWs);
                            XMLCurrNodeWs := XMLNewChildWs;
                            XmlMgt.AddElement(XMLCurrNodeWs, 'BolsaPlasticoItem', '', LbNameSpaceLib, XMLNewChildWs);
                            XMLCurrNodeWs := XMLNewChildWs;

                            TotalBolsa += RecSalesInvoiceLine.Quantity * DecPriceWithOutVAT;
                            XmlMgt.AddElement(XMLCurrNodeWs, 'Cantidad', FORMAT(RecSalesInvoiceLine.Quantity, 0, '<Precision,5:5><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorImpuesto', FORMAT(TotalBolsa, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorImpuestoUnitario', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ImpuestoItem
                            XMLNewChildWs := XMLCurrNodeWs;
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ImpuestoItem
                            XMLNewChildWs := XMLCurrNodeWs;

                        end;

                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //BolsaPlasticoItem
                        XMLNewChildWs := XMLCurrNodeWs;

                        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                            IF RecSalesInvoiceLine."Inv. Discount Amount" > 0 THEN begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoCargoDetalle', '', LbNameSpaceLib, XMLNewChildWs);
                                XMLCurrNodeWs := XMLNewChildWs;

                                XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoDetalle', '', LbNameSpaceLib, XMLNewChildWs);
                                XMLCurrNodeWs := XMLNewChildWs;

                                XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoAplicado', '00', LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '0', LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT(RecSalesInvoiceLine."Line Amount" + RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                XmlMgt.AddElement(XMLCurrNodeWs, 'Porcentaje', FORMAT(RecSalesInvoiceLine."Line Discount %", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoDetalle
                                XMLNewChildWs := XMLCurrNodeWs;
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoDetalle
                                XMLNewChildWs := XMLCurrNodeWs;

                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteDetalle
                                XMLNewChildWs := XMLCurrNodeWs;

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoCargoDetalleIGV', '', LbNameSpaceLib, XMLNewChildWs);
                                // XMLCurrNodeWs := XMLNewChildWs;

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoDetalleIGV', '', LbNameSpaceLib, XMLNewChildWs);
                                // XMLCurrNodeWs := XMLNewChildWs;


                                // XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '0', LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."Line Discount %" / 100), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                // XmlMgt.AddElement(XMLCurrNodeWs, 'Porcentaje', FORMAT(RecSalesInvoiceLine."Line Discount %" / 100, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //DescuentoCargoDetalleIGV
                                // XMLNewChildWs := XMLCurrNodeWs;
                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //DescuentoCargoDetalleIGV
                                // XMLNewChildWs := XMLCurrNodeWs;

                                // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoDetalleIGV
                                // XMLNewChildWs := XMLCurrNodeWs;


                            end;
                        end;

                        if VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::General then begin
                            IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BOLSA') THEN begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', FORMAT((RecSalesInvoiceLine.Quantity * DecPriceWithOutVAT) + RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end
                            else begin
                                if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                    // XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', FORMAT(Round(RecSalesInvoiceLine."Line Amount" * (RecSalesInvoiceLine."VAT %" / 100), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);                                
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', FORMAT(Round(RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end
                                else begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', FORMAT(RecSalesInvoiceLine."Amount Including VAT" - RecSalesInvoiceLine."VAT Base Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end;

                            end;
                        end
                        else begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoTotal', '0.00', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;
                        //MultiDescripcion
                        XmlMgt.AddElement(XMLCurrNodeWs, 'Item', FORMAT(RecSalesInvoiceLine."Line No." / 10000), LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        XmlMgt.AddElement(XMLCurrNodeWs, 'Nota', RecSalesInvoiceLine."No.", LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                        if (VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Bonificacion]) then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'PrecioVentaItem', '0.00', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end
                        ELSE begin
                            if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                // XmlMgt.AddElement(XMLCurrNodeWs, 'PrecioVentaItem', FORMAT(Round(RecSalesInvoiceLine."Line Amount" * (1 + (RecSalesInvoiceLine."VAT %" / 100)), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.AddElement(XMLCurrNodeWs, 'PrecioVentaItem', FORMAT(RecSalesInvoiceLine."Amount Including VAT", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end
                            else begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'PrecioVentaItem', FORMAT(RecSalesInvoiceLine."Amount Including VAT", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end;
                        end;

                        if VATProdPostGr."Type VAT" = VATProdPostGr."Type VAT"::General then begin
                            if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end
                            else begin
                                if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end
                                else begin
                                    if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    end
                                    else begin
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    end;
                                end;
                            end;
                        end
                        else begin
                            if VATProdPostGr."Type VAT" in [VATProdPostGr."Type VAT"::Inafecto, VATProdPostGr."Type VAT"::"Transferencia Gratuita", VATProdPostGr."Type VAT"::Exportacion, VATProdPostGr."Type VAT"::Exonerado, VATProdPostGr."Type VAT"::Bonificacion] then begin
                                if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end
                                else begin
                                    if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    end
                                    else begin
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(Round(((DecPriceWithOutVAT) * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    end;
                                end;

                            end

                        end;

                        if RecUnitOfMesure.Get(RecSalesInvoiceLine."Unit of Measure Code") then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'UnidadComercial', RecUnitOfMesure."LOCPE_Unit of Measure SUNAT", LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end
                        else begin
                            if (RecSalesInvoiceLine."Unit of Measure Code" <> '') then begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'UnidadComercial', RecSalesInvoiceLine."Unit of Measure Code", LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end
                            else begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'UnidadComercial', 'NIU', LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                            end;

                        end;

                        case VATProdPostGr."Type VAT" of
                            VATProdPostGr."Type VAT"::General:
                                begin

                                    if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                        //XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs); cambio sunat
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Inv. Discount Amount", 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                    end
                                    else begin
                                        if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                            // XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(Round((DecPriceWithOutVAT * RecSalesInvoiceLine.Quantity) - RecSalesInvoiceLine."Line Discount Amount", 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                        end
                                        else begin
                                            //XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                        end;
                                    end;


                                    TotalGravado := TotalBase;
                                    TotalIgvBase += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                                end;
                            VATProdPostGr."Type VAT"::Exportacion:
                                begin
                                    if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                        //XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(DecPriceWithOutVAT - (RecSalesInvoiceLine."Inv. Discount Amount" / RecSalesInvoiceLine.Quantity), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(round(DecPriceWithOutVAT - (RecSalesInvoiceLine."Inv. Discount Amount" / RecSalesInvoiceLine.Quantity), 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                    end
                                    else begin
                                        if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                            //XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(Round((DecPriceWithOutVAT - (RecSalesInvoiceLine."Line Discount Amount" / RecSalesInvoiceLine.Quantity)), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(Round((DecPriceWithOutVAT - (RecSalesInvoiceLine."Line Discount Amount" / RecSalesInvoiceLine.Quantity)), 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                        end
                                        else begin
                                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(Round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                        end;
                                    end;
                                    // XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                    //                                TotalExportacion += TotalBase;
                                end;

                            VATProdPostGr."Type VAT"::Inafecto:
                                begin
                                    // XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                    //                              TotalInafecto += TotalBase;
                                end;
                            VATProdPostGr."Type VAT"::"Transferencia Gratuita":
                                begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', '0.00', LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                    //                                TotalGratuito += TotalBase;
                                    TotalImpGratuito += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                                end;
                            VATProdPostGr."Type VAT"::Bonificacion:
                                begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', '0.00', LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                    //                                TotalGratuito += TotalBase;
                                    TotalImpGratuito += RecSalesInvoiceLine."Amount Including VAT" - ROUND(RecSalesInvoiceLine."VAT Base Amount", 0.01);
                                end;
                            VATProdPostGr."Type VAT"::Exonerado:
                                begin
                                    // XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitario', FORMAT(round(DecPriceWithOutVAT, 0.0001, '>')).Replace(',', ''), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                    //                              TotalExonerado += TotalBase;
                                end;
                        end;

                        case VATProdPostGr."Type VAT" of
                            VATProdPostGr."Type VAT"::General:
                                begin
                                    IF (RecSalesInvoiceLine."VAT Prod. Posting Group" = 'BOLSA') THEN begin
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithOutVAT + DecPriceWithVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    end
                                    else begin
                                        if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                            if (LlaveAnticipoCabecera > 0) then begin
                                                XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv',
                                                FORMAT(Round(DecPriceWithOutVAT * (1 + (RecSalesInvoiceLine."VAT %" / 100)), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                            end
                                            else begin
                                                XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);//FORMAT(Round(RecSalesInvoiceLine."Line Amount" * (1 + (RecSalesInvoiceLine."VAT %" / 100)), 0.01), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                            end;
                                        end
                                        else begin
                                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                        end;
                                    end;
                                end;
                            VATProdPostGr."Type VAT"::Exportacion:
                                begin
                                    if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                        XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithOutVAT - (RecSalesInvoiceLine."Inv. Discount Amount" / RecSalesInvoiceLine.Quantity), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                    end
                                    else begin
                                        if (RecSalesInvoiceLine."Line Discount Amount" <> 0) then begin
                                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithOutVAT - (RecSalesInvoiceLine."Line Discount Amount" / RecSalesInvoiceLine.Quantity), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                        end
                                        else begin
                                            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                        end;
                                    end;
                                end;
                            VATProdPostGr."Type VAT"::Inafecto:
                                begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end;
                            VATProdPostGr."Type VAT"::"Transferencia Gratuita":
                                begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                end;
                            VATProdPostGr."Type VAT"::Bonificacion:
                                begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'ValorVentaUnitarioIncIgv', FORMAT(DecPriceWithOutVAT, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                                end;
                        end;
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteDetalle
                        XMLNewChildWs := XMLCurrNodeWs;
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteDetalle
                        XMLNewChildWs := XMLCurrNodeWs;
                    END;
                END;
            UNTIL RecSalesInvoiceLINE.NEXT = 0;
        END;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteDetalle
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteGrillaCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        //LINEA 1
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteGrillaCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'BCO BCP', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor1', '1941414977095', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor2', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor3', '1941412442100', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor4', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        //LINEA 2
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteGrillaCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'BCO SCOTIABANK ', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor1', '0401038205', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor2', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor3', '0401038204', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor4', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        //LINEA 3
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteGrillaCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'BCO CONTINENTAL', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor1', '001103330100053', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor2', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor3', '001103330100053', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor4', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        //LINEA 4
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteGrillaCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'BCO INTERBANK', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor1', '0413000354210', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor2', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor3', '0413000346291', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor4', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        //LINEA 5
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteGrillaCuenta', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'BCO DE LA NACION ', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor1', '00015000783', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor2', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor3', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Valor4', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;


        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteGrillaCuenta
        XMLNewChildWs := XMLCurrNodeWs;


        //guia remision
        // XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteGuia', '', LbNameSpaceLib, XMLNewChildWs);
        // XMLCurrNodeWs := XMLNewChildWs;

        // XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteGuia', '', LbNameSpaceLib, XMLNewChildWs);
        // XMLCurrNodeWs := XMLNewChildWs;

        // XmlMgt.AddElement(XMLCurrNodeWs, 'Numero', '001', LbNameSpaceLib, XMLNewChildWs);
        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        // XmlMgt.AddElement(XMLCurrNodeWs, 'Serie', '000001', LbNameSpaceLib, XMLNewChildWs);
        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        // XmlMgt.AddElement(XMLCurrNodeWs, 'TipoDocReferencia', '09', LbNameSpaceLib, XMLNewChildWs);
        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteGuia
        // XMLNewChildWs := XMLCurrNodeWs;

        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteGuia
        // XMLNewChildWs := XMLCurrNodeWs;

        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteGuia
        // XMLNewChildWs := XMLCurrNodeWs;


        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '07') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '08') then begin
            //ComprobanteMotivosDocumentos / ENComprobanteMotivoDocumento nota de credito 

            XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteMotivosDocumentos', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteMotivoDocumento', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            if (RecSalesInvoiceHeaderNC."LOCPE_NC Type SUNAT" = '') then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivoEmision', '01', LbNameSpaceLib, XMLNewChildWs);
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivoEmision', RecSalesInvoiceHeaderNC."LOCPE_NC Type SUNAT", LbNameSpaceLib, XMLNewChildWs);
            end;

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.AddElement(XMLCurrNodeWs, 'NumeroDocRef', CopyStr(RecSalesInvoiceHeaderNC."LOCPE_No. Corrected Doc. FR", 6, 8), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.AddElement(XMLCurrNodeWs, 'SerieDocRef', CopyStr(RecSalesInvoiceHeaderNC."LOCPE_No. Corrected Doc. FR", 1, 4), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.AddElement(XMLCurrNodeWs, 'Sustentos', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteMotivoDocumentoSustento', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            RecSunat.Reset();
            RecSunat.SetRange("LOCPE_Table Code", '41');
            RecSunat.SetRange("LOCPE_Sunat Code", RecSalesInvoiceHeaderNC."LOCPE_NC Type SUNAT");

            if (RecSunat.FindFirst()) then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Sustento', RecSunat.LOCPE_Description, LbNameSpaceLib, XMLNewChildWs);
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Sustento', 'ANULACION', LbNameSpaceLib, XMLNewChildWs);
            end;

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteMotivoDocumentoSustento
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteMotivoDocumentoSustento
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Sustentos
            XMLNewChildWs := XMLCurrNodeWs;

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteMotivoDocumento
            XMLNewChildWs := XMLCurrNodeWs;

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteMotivosDocumentos
            XMLNewChildWs := XMLCurrNodeWs;


            //ComprobanteNotaCreditoDocRef / ENComprobanteNotaDocRef
            XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobanteNotaCreditoDocRef', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobanteNotaDocRef', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'FechaDocRef', format(RecsalesReferencia."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.AddElement(XMLCurrNodeWs, 'Numero', CopyStr(RecSalesInvoiceHeaderNC."LOCPE_No. Corrected Doc. FR", 6, 8), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.AddElement(XMLCurrNodeWs, 'Serie', CopyStr(RecSalesInvoiceHeaderNC."LOCPE_No. Corrected Doc. FR", 1, 4), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.AddElement(XMLCurrNodeWs, 'TipoComprobante', RecsalesReferencia."LOCPE_Doc. Type SUNAT", LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteNotaDocRef
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobanteNotaDocRef
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobanteNotaCreditoDocRef
            XMLNewChildWs := XMLCurrNodeWs;


        end;


        XmlMgt.AddElement(XMLCurrNodeWs, 'ComprobantePropiedadesAdicionales', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
            TotalImporte := ((TotalIGVFinal - TotalIgvBaseAnticipo) + (TotalBaseDes - TotalBaseAnticipo)) - RecSalesInvoiceLine."Inv. Discount Amount";
            //TotalImporte := ((TotalIGVFinal - TotalIgvBaseAnticipo) + (TotalBaseDes - TotalBaseAnticipo));
        end
        else begin
            TotalImporte := ((TotalIGV - TotalIgvBaseAnticipo) + (TotalBaseDes - TotalBaseAnticipo));
        end;

        if (TotalBolsa <> 0) then begin
            TotalImporte := TotalImporte + TotalBolsa
        end;

        IF (LlaveGravada <> 0) THEN begin
            if (LlaveGratuito <> 0) then begin
                TotalImporte := (TotalBaseMixto - TotalBaseAnticipo) + (TotalImpuestoMixto - TotalIgvBaseAnticipo);
            end;
        end
        else begin
            if (LlaveGratuiInafecto <> 0) then begin
                TotalImporte := 0;
            end;

        end;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobantePropiedadesAdicionales', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        //Monto en letras
        XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '1000', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        IF (RecSalesInvoiceHeaderNC."LOCPE_Free Document" = false) then begin

            XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', DIN_FUN_CONVERTIR_NUMEROS_LETRA(TotalImporte + TotalRecargo, RecSalesInvoiceHeaderNC."Currency Code"), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        END
        else begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', DIN_FUN_CONVERTIR_NUMEROS_LETRA(0, RecSalesInvoiceHeaderNC."Currency Code"), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        end;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobantePropiedadesAdicionales
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobantePropiedadesAdicionales
        XMLNewChildWs := XMLCurrNodeWs;



        IF (RecSalesInvoiceHeaderNC."LOCPE_Free Document" = true) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobantePropiedadesAdicionales', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '1002', LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', 'TRANSFERENCIA GRATUITA DE UN BIEN Y/O SERVICIO PRESTADO GRATUITAMENTE', LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobantePropiedadesAdicionales
            XMLNewChildWs := XMLCurrNodeWs;

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobantePropiedadesAdicionales
            XMLNewChildWs := XMLCurrNodeWs;
        end;

        IF (RecSalesInvoiceHeaderNC."LOCPE_Sales Detraccion" = true) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'ENComprobantePropiedadesAdicionales', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '2006', LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', 'Operación sujeta a detracción', LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobantePropiedadesAdicionales
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENComprobantePropiedadesAdicionales
            XMLNewChildWs := XMLCurrNodeWs;
        end;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ComprobantePropiedadesAdicionales
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'CorreoElectronico', RecCustomer."E-Mail", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
            if (LlaveAnticipo = 0) then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;
                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    if (LlaveExportacion = 0) then begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivo', '02', LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end
                    else begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivo', '03', LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end;

                end;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'Descuento Global 1', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '0', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT((TotalBaseDes), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'PorcentajeAplicado', FORMAT(((RecSalesInvoiceLine."Inv. Discount Amount" / TotalBaseDes) * 100), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //DescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                if LlaveAnticipoCabecera = 1 then begin
                    if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin

                        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivo', '04', LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end;

                    XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'Anticipo 1', LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '0', LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                    if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT((TotalBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end;

                    SalesInvHeadePrepagoL2.RESET();
                    SalesInvHeadePrepagoL2.SETRANGE(SalesInvHeadePrepagoL2."Order No.", RecSalesInvoiceHeaderNC."LOCPE_No. Corrected Doc. NC");

                    IF SalesInvHeadePrepagoL2.FINDSET() THEN begin
                        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'PorcentajeAplicado', '100.00', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;
                    end;
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                    XMLNewChildWs := XMLCurrNodeWs;

                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                    XMLNewChildWs := XMLCurrNodeWs;

                    XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                    XMLCurrNodeWs := XMLNewChildWs;
                end;

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    if (LlaveExportacion = 0) then begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivo', '02', LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end
                    else begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivo', '03', LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end;

                end;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'Descuento Global 1', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '0', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT((TotalBaseDes - TotalBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'PorcentajeAplicado', FORMAT(((RecSalesInvoiceLine."Inv. Discount Amount" / (TotalBaseDes - TotalBaseAnticipo)) * 100), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //DescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

            end;

        end
        else begin
            if (LlaveAnticipo > 0) then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;
                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin

                    XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivo', '04', LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'Anticipo 1', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '0', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT((TotalBaseAnticipo), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'PorcentajeAplicado', '100.00', LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //DescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;
            end;
            IF (TotalRecargo > 0) THEN begin

                XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'ENDescuentoCargoCabecera', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;
                XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoMotivo', '50', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                XmlMgt.AddElement(XMLCurrNodeWs, 'Descripcion', 'Recargo Global', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Indicador', '1', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', FORMAT(TotalRecargo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '07') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '07') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'MontoBase', FORMAT((TotalBaseDes), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;

                if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '07') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '07') then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'PorcentajeAplicado', FORMAT(((TotalRecargo / TotalBaseDes) * 100), 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //DescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;
            end;
        end;

        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
            IF (LlaveExportacion > 1) THEN begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoNoAfecto', FORMAT(RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'DescuentoGlobal', FORMAT(RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end;
        end;

        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
            if (RecSalesInvoiceHeaderNC."LOCPE_Sales Detraccion" = true) then begin


                XmlMgt.AddElement(XMLCurrNodeWs, 'Detraccion', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'ENDetraccion', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'BienesServicios', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'ENBienesServicios', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '2003', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', RecSalesInvoiceHeaderNC.LOCPE_SalesDetractionServType, LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENBienesServicios
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENBienesServicios
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //BienesServicios
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Monto', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'ENMonto', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '2003', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', FORMAT(RecSalesInvoiceHeaderNC."LOCPE_Sales Detraction Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENMonto
                XMLNewChildWs := XMLCurrNodeWs;
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENMonto
                XMLNewChildWs := XMLCurrNodeWs;
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Monto
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'NumeroCuenta', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;
                XmlMgt.AddElement(XMLCurrNodeWs, 'ENNumeroCuenta', '', LbNameSpaceLib, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Codigo', '3001', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoFormaPago', '999', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XmlMgt.AddElement(XMLCurrNodeWs, 'Valor', '00000522910', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENDescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //DescuentoCargoCabecera
                XMLNewChildWs := XMLCurrNodeWs;
            end;

        end;
        XmlMgt.AddElement(XMLCurrNodeWs, 'FechaEmision', FORMAT(RecSalesInvoiceHeaderNC."Document Date", 0, '<Year4>-<Month,2>-<Day,2>'), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        RecPaymentTerms.Reset();
        RecPaymentTerms.SetRange(Code, RecSalesInvoiceHeaderNC."Payment Terms Code");
        IF RecPaymentTerms.FINDSET() THEN begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'FormaPago', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'ENFormaPago', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin

                XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoFormaPago', '999', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end;
            XmlMgt.AddElement(XMLCurrNodeWs, 'FechaVencimiento', FORMAT(RecSalesInvoiceHeaderNC."Due Date", 0, '<Year4>-<Month,2>-<Day,2>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') or (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'NotaInstruccion', RecPaymentTerms.Description, LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end;

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENFormaPago
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENFormaPago
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //FormaPago
            XMLNewChildWs := XMLCurrNodeWs;
        end;

        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '01') then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'GlosaAgenteRetencion', 'Somos agentes de retención del IGV según R.S. N° 180-2016 /SUNAT a partir 01/09/2016', LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        end;

        XmlMgt.AddElement(XMLCurrNodeWs, 'HoraEmision', FORMAT(CurrentDateTime, 0, '<Hours24,2><Filler Character,0>:<Minutes,2>:<Seconds,2>'), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        if (RecSalesInvoiceHeaderNC."LOCPE_Free Document" = true) then begin
            TotalImporte := 0;
        end;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ImporteTotal', FORMAT(TotalImporte + TotalRecargo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);



        //consultar el campo incotrerm

        if (RecSalesInvoiceHeaderNC."Currency Code" = '') then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Moneda', 'PEN', LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        end
        ELSE begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Moneda', RecSalesInvoiceHeaderNC."Currency Code", LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        end;

        //MONTOS TOTALES
        XmlMgt.AddElement(XMLCurrNodeWs, 'MontosTotales', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        if (TotalExonerado <> 0) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Exonerado', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(TotalExonerado, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Exonerado
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Exonerado
            XMLNewChildWs := XMLCurrNodeWs;
        end;
        if (TotalExportacion <> 0) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Exportacion', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(TotalExportacion, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Exportacion
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Exportacion
            XMLNewChildWs := XMLCurrNodeWs;
        end;

        if (TotalGratuito <> 0) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Gratuito', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'GratuitoImpuesto', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'Base', FORMAT(TotalGratuito, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorImpuesto', FORMAT(TotalImpGratuito, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //GratuitoImpuesto
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //GratuitoImpuesto
            XMLNewChildWs := XMLCurrNodeWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(TotalGratuito, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Gratuito
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Gratuito
            XMLNewChildWs := XMLCurrNodeWs;
        end;

        if (TotalGravado - RecSalesInvoiceLine."Inv. Discount Amount" > 0) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Gravado', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'GravadoIGV', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Base', FORMAT(TotalGravado - RecSalesInvoiceLine."Inv. Discount Amount" - TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Base', FORMAT(TotalGravado - TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end;
            XmlMgt.AddElement(XMLCurrNodeWs, 'Porcentaje', '18.00', LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorImpuesto', FORMAT(TotalIgvBase - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //GravadoIGV
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //GravadoIGV
            XMLNewChildWs := XMLCurrNodeWs;

            if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(TotalGravado - RecSalesInvoiceLine."Inv. Discount Amount" - TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(TotalGravado - TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end;

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Gravado
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Gravado
            XMLNewChildWs := XMLCurrNodeWs;
        end;

        IF (TotalBolsa <> 0) THEN begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'ImpuestoBolsaPlastico', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'ValorImpuesto', FORMAT(TotalBolsa, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Inafecto
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Inafecto
            XMLNewChildWs := XMLCurrNodeWs;
        end;
        if (TotalInafecto <> 0) then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Inafecto', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            if LlaveAnticipoCabecera <> 0 then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(0, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'Total', FORMAT(TotalInafecto, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
            end;


            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Inafecto
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Inafecto
            XMLNewChildWs := XMLCurrNodeWs;
        end;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //MontosTotales
        XMLNewChildWs := XMLCurrNodeWs;

        // XmlMgt.AddElement(XMLCurrNodeWs, 'Multiglosa', '', LbNameSpaceLib, XMLNewChildWs);
        // XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'NroOrdenCompra', RecSalesInvoiceHeaderNC."External Document No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);



        XmlMgt.AddElement(XMLCurrNodeWs, 'Numero', COPYSTR(RecSalesInvoiceHeaderNC."No.", 6, 8), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


        XmlMgt.AddElement(XMLCurrNodeWs, 'RazonSocial', RecCustomer.Name, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Receptor', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENReceptor', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Calle', RecCustomer.Address, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        RecCountryCust.GET(RecCustomer."Country/Region Code");
        XmlMgt.AddElement(XMLCurrNodeWs, 'CodPais', RecCountryCust."LOCPE_Sunat Code", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        IF NOT RecPostCodeCust.GET(RecCustomer."Post Code", RecCustomer.City) THEN
            CLEAR(RecPostCodeCust);

        DepartmentCode := CopyStr(RecPostCodeCust."LOCPE_Department", 1, 29);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Departamento', DepartmentCode, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        DistrictCode := CopyStr(RecPostCodeCust."LOCPE_District", 1, 29);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Distrito', DistrictCode, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        ProvinceCode := CopyStr(RecPostCodeCust."LOCPE_Province", 1, 29);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Provincia', ProvinceCode, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Urbanizacion', '', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENReceptor
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENReceptor
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Receptor
        XMLNewChildWs := XMLCurrNodeWs;

        IF RecCustomer."LOCPE_DocTypeIdentitySUNAT" = '6' THEN //Campo desconocido
             begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', RecCustomer."VAT Registration No.", LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        end
        ELSE begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', RecCustomer."LOCPE_DNI/CE/Other", LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        end;
        XmlMgt.AddElement(XMLCurrNodeWs, 'Serie', COPYSTR(RecSalesInvoiceHeaderNC."No.", 1, 4), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Sucursal', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENSucursal', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        IF NOT RecPostCode.GET(RecCompanyInformation."Post Code", RecCompanyInformation.City) THEN
            CLEAR(RecPostCode);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Departamento', recPostCode."LOCPE_Department", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Direccion', RecCompanyInformation.Address, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Distrito', recPostCode.LOCPE_District, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Fax', RecCompanyInformation."Fax No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Nombre', 'Tienda Principal', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Provincia', recPostCode.LOCPE_Province, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Telefono', RecCompanyInformation."Phone No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Ubigeo', RecCompanyInformation."Post Code", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENSucursal
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENSucursal
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Sucursal
        XMLNewChildWs := XMLCurrNodeWs;


        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.AddElement(XMLCurrNodeWs, 'ENTexto', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto1', 'Almacen', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto2', RecSalesInvoiceHeaderNC."User ID", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto3', 'Si hubiera algún defecto en el producto vendido nuestra responsabilidad únicamente se limita a su costo o reposición. El riesgo de la pérdida, daño o destrucción de el/los bien/es pasará al comprador a partir del momento que el/los mismo/s sea/n entregado al transportador para su envío al domicilio del comprador. ALITECNO S.A.C., dentro del periodo de garantía, será responsable por el buen estado y el funcionamiento del equipo y/o producto y/o repuestos y la conformidad de los mismos con las condiciones de idoneidad, calidad y seguridad legalmente exigible o las ofrecidas, sin contraprestación adicional al precio del equipo y/o producto y/o perjuicios derivados de los repuestos, no siendo en consecuencia responsable de los daños y perjuicios derivados de los desperfectos de estos,tales como pérdidas de producción, de insumos, de empaques, de ventas, reclamos de clientes del consumidor,costos de capital, entre otros. La Factura Negociable no requiere ser protestada por falta de pago', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto4', 'El plazo del protesto podrá ser prorrogado por el tenedor por el plazo que este establezca, sin que sea necesaria la intervención del obligado principal ni los solidarios.En caso de mora, este título generará las tasas de interés compensatorio  y moratorio más altas que la ley permita a su tenedor.Se cobrará almacenaje si el costo del servicio no es aceptado y/o el equipo, producto o repuestos no son recogidos por EL CLIENTE, después de 30 días naturales de que los mismos se encuentren a su disposición. Costo por día de almacenaje USD 10 por metro cubico o fracción. Transcurridos los 60 días naturales desde que el equipo y/o producto y/o repuestos se encuentren a disposición de EL CLIENTE sin ser recogidos por éste, ALITECNO S.A.C. podrá cursarle una carta notarial requiriéndolo para que recoja equipo producto y/o repuestos, en un plazo de quince días naturales, bajo apercibimiento de que, en caso contrario, el contrato queda resuelto de pleno derecho, pudiendo ALITECNO SAC en tal caso ', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto5', 'disponer de los mismos en la forma que estime conveniente, quedando a disposición de EL CLIENTE el saldo de dinero que hubiere entregado o el saldo del precio venta del bien, al que previamente se descontarán  los costos del almacenaje, servicio, etc.Toda reprogramación del servicio técnico debido a causa imputable a EL CLIENTE no comunicada con la debida antelación, se generará un nuevo costo de movilidad.ALITECNO S.A.C., conforme a lo establecido en el artículo 1823 del Código Civil, no será responsable por pérdida, extravío, sustracción, deterioro, destrucción de equipo y/o producto y/o repuestos que se encuentren en sus almacenes, debido a circunstancias o factores ajenos a su control, como son el caso fortuito y la fuerza mayor. Para la solución de todas las desavenencias o controversias que pudieran derivarse del cobro de la presente factura o boleta de venta y las condiciones aquí establecidas, las partes se someten a los jueces y tribunales de la ciudad Lima. ', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto6', 'Incorporado al Régimen de Buenos Contribuyente según Resolución N° 0210050004553 a partir del 01/04/2018', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto7', 'El tipo de cambio  es el establecido por Alitecno en la fecha de pago, si el cliente decide cancelar en soles. Condiciones de garantía de las maquinas en www.alitecnoperu.com', LbNameSpaceLib, XMLNewChildWs);
        //XmlMgt.AddElement(XMLCurrNodeWs, 'Texto7', 'Las Condiciones de la Garantía de las Máquinas se encuentran en : www.alitecnoperu.com/garantia', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto8', '-', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Texto9', RecCompanyInformation.Address, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENTexto
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENTexto
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Texto
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoComprobante', RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoDocumentoIdentidad', RecCustomer.LOCPE_DocTypeIdentitySUNAT, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoDocumentoReferenciaGuia', RecCustomer.LOCPE_DocTypeIdentitySUNAT, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoOperacion', RecSalesInvoiceHeaderNC."LOCPE_Operation Type FE", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoPlantilla', 'ST1', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        if (LlaveGravada <> 0) then begin
            if (LlaveGratuito <> 0) then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalImpuesto', FORMAT(TotalImpuestoMixto - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end
            else begin
                if (RecSalesInvoiceHeaderNC."LOCPE_Free Document" = false) then begin
                    if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'TotalImpuesto', FORMAT(TotalIGVFinal - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end
                    else begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'TotalImpuesto', FORMAT(TotalIGV - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end;
                end
                else begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'TotalImpuesto', '0.0', LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                end;
            end;
        end
        else begin
            if (RecSalesInvoiceHeaderNC."LOCPE_Free Document" = false) then begin
                if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'TotalImpuesto', FORMAT(TotalIGVFinal - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end
                else begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'TotalImpuesto', FORMAT(TotalIGV - TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;
            end
            else begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalImpuesto', '0.0', LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            end;
        end;

        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '07') then begin

            IF (LlaveGravada = 0) AND (LlaveExportacion > 0) AND (RecSalesInvoiceLine."Inv. Discount Amount" > 0) THEN begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalPrecioVenta', FORMAT(TotalExportacion + TotalIgvBaseAnticipo + TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end
            ELSE begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalPrecioVenta', FORMAT(TotalImporte + TotalIgvBaseAnticipo + TotalBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end;
            if (LlaveAnticipoCabecera > 0) then begin
                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalPrepago', FORMAT(TotalBaseAnticipo + TotalIgvBaseAnticipo, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
            end;

            if (LlaveGravada <> 0) then begin
                if (LlaveGratuito <> 0) then begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', FORMAT(TotalBaseMixto, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end
                else begin
                    if (RecSalesInvoiceHeaderNC."LOCPE_Free Document" = false) then begin

                        if (LlaveGratuiInafecto <> 0) then begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', '0.00', LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end
                        else begin
                            if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                                if (LlaveAnticipo <> 0) then begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', FORMAT(TotalBase - RecSalesInvoiceLine."Inv. Discount Amount", 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end
                                else begin
                                    XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', FORMAT(TotalImporte - TotalIGVFinal, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                                end;

                            end
                            else begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', FORMAT(TotalBaseDes, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end;
                        end;

                    end
                    else begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', '0.00', LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end;
                end;
            end
            else begin
                if (RecSalesInvoiceHeaderNC."LOCPE_Free Document" = false) then begin

                    if (LlaveGratuiInafecto <> 0) then begin
                        XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', '0.00', LbNameSpaceLib, XMLNewChildWs);
                        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                    end
                    else begin
                        if (RecSalesInvoiceLine."Inv. Discount Amount" <> 0) then begin
                            IF (LlaveGravada = 0) AND (LlaveExportacion > 0) AND (RecSalesInvoiceLine."Inv. Discount Amount" > 0) THEN begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', FORMAT(TotalExportacion, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                            end
                            else begin
                                XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', FORMAT(TotalImporte - TotalIGVFinal, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                            end;
                        end
                        else begin
                            XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', FORMAT(TotalBaseDes, 0, '<Precision,2:2><Integer><Decimals><Comma,.>'), LbNameSpaceLib, XMLNewChildWs);
                            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                        end;
                    end;

                end
                else begin
                    XmlMgt.AddElement(XMLCurrNodeWs, 'TotalValorVenta', '0.00', LbNameSpaceLib, XMLNewChildWs);
                    XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                end;
            end;



        end;

        if (RecSalesperson.Name <> '') then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'Vendedor', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;
            XmlMgt.AddElement(XMLCurrNodeWs, 'ENVendedor', '', LbNameSpaceLib, XMLNewChildWs);
            XMLCurrNodeWs := XMLNewChildWs;

            XmlMgt.AddElement(XMLCurrNodeWs, 'Nombre', RecSalesperson.Name, LbNameSpaceLib, XMLNewChildWs);
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENVendedor
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENVendedor
            XMLNewChildWs := XMLCurrNodeWs;
            XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Vendedor
            XMLNewChildWs := XMLCurrNodeWs;
        end;
        XmlMgt.AddElement(XMLCurrNodeWs, 'VersionUbl', '2.1', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        //FIN DE COMPROBANTE

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENComprobante
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENComprobante
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENEmpresa', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Calle', RecCompanyInformation.Address, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'CodDistrito', RecCompanyInformation."Post Code", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'CodPais', RecGLSetup."Codigo Pais", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoEstablecimientoSUNAT', '0001', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoTipoDocumento', RecCompanyInformation."LOCPE_Doc. Type SUNAT", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Correo', RecCompanyInformation."E-Mail", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Departamento', recPostCode."LOCPE_Department", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Distrito', recPostCode.LOCPE_District, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Fax', RecCompanyInformation."Fax No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Provincia', recPostCode.LOCPE_Province, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'RazonSocial', RecCompanyInformation.Name, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', RecCompanyInformation."VAT Registration No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Telefono', RecCompanyInformation."Phone No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Urbanizacion', '.', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Web', RecCompanyInformation."Home Page", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENEmpresa
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENEmpresa
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oGeneral
        XMLNewChildWs := XMLCurrNodeWs;

        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '07') then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'oTipoComprobante', 'NotaCredito', LbNameSpaceTem, XMLNewChildWs);
        end;
        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '03') then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'oTipoComprobante', '1', LbNameSpaceTem, XMLNewChildWs);
        end;
        if (RecSalesInvoiceHeaderNC."LOCPE_Doc. Type SUNAT" = '08') then begin
            XmlMgt.AddElement(XMLCurrNodeWs, 'oTipoComprobante', '3', LbNameSpaceTem, XMLNewChildWs);
        end;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Cadena', '', LbNameSpaceTem, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoCodigo', '1', LbNameSpaceTem, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoBarras', '', LbNameSpaceTem, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoHash', '', LbNameSpaceTem, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'ListaError', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ENErrorComunicacion', '', LbNameSpaceDll, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //ListaError
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //ListaError
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'IdComprobanteCliente', CopyStr(RecSalesInvoiceHeaderNC."No.", 6, 8), LbNameSpaceTem, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Otorgar', '1', LbNameSpaceTem, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);



        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestDownloadsDocuments(var XmlDocWs: XmlDocument;
    CompanyInfo: Record "Company Information";
    DocType: Code[20];
    UserName: Text[50];
    Password: Text[50];
    DocID: Code[20])

    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        Numerox: Integer;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceTem: Label 'http://tempuri.org/', Locked = true;
        LbNameSpaceLib: Label 'http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion', Locked = true;
        LbNameSpaceArr: Label 'http://schemas.microsoft.com/2003/10/Serialization/Arrays', Locked = true;
        LbNameSpaceDll: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio', Locked = true;

        LbNameSpaceLoad: Label 'http://ws.seres.com/wsdl/20150301/LoadsDocuments/', Locked = true;
        LbNameSpaceWsse: label 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd', Locked = true;

    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:dll="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio" xmlns:lib="http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Obtener_PDF', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENPeticion', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Autenticacion', '', LbNameSpaceDll, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Clave', Password, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', UserName, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        evaluate(Numerox, CopyStr(DocID, 6, 8));

        XmlMgt.AddElement(XMLCurrNodeWs, 'IndicadorComprobante', '1', LbNameSpaceDll, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Numero', FORMAT(Numerox, 0), LbNameSpaceDll, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', CompanyInfo."VAT Registration No.", LbNameSpaceDll, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Serie', CopyStr(DocID, 1, 4), LbNameSpaceDll, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoComprobante', DocType, LbNameSpaceDll, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Cadena', '?', LbNameSpaceTem, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Obtener_PDF
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        // DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestHangingDownloads()
    var
        XmlDocWs: XmlDocument;
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        LbNameSpaceSoap: Label 'http://www.w3.org/2003/05/soap-envelope', Locked = true;
        LbNameSpaceHan: Label 'http://ws.seres.com/wsdl/20150301/HangingDownloads/', Locked = true;
        LbNameSpaceWsse: label 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd', Locked = true;

    begin
        XmlStr := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:han="http://ws.seres.com/wsdl/20150301/HangingDownloads/">' +
                  '</soap:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Header', '', 'soap', LbNameSpaceSoap, XMLNewChildWs);

        /*
                XMLCurrNodeWs := XMLNewChildWs;
                XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Security', '', 'wsse', LbNameSpaceWsse, XMLNewChildWs);
                //XmlMgt.AddAttribute(XMLCurrNodeWs, 'soap:mustUnderstand', 'true');
                XMLCurrNodeWs := XMLNewChildWs;
                XmlMgt.AddElement(XMLCurrNodeWs, 'UsernameToken', '', LbNameSpaceWsse, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Username', UserName, LbNameSpaceWsse, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                XmlMgt.AddElement(XMLCurrNodeWs, 'Password', Password, LbNameSpaceWsse, XMLNewChildWs);
                XmlMgt.AddAttribute(XMLCurrNodeWs, 'Type', 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText');
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XMLNewChildWs := XMLCurrNodeWs;
        */

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Header

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Body', '', 'soap', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'queryDownloads', '', 'han', LbNameSpaceHan, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'parameters', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'EFacturaService', 'PERU', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //EFacturaService
        XMLCurrNodeWs := XMLNewChildWs;

        // >>

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdentification', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdCountry', 'PE', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdCountry
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdType', '6', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdType
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdNumber', '20563249090', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdNumber
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdentification
        XMLCurrNodeWs := XMLNewChildWs;

        // <<

        XmlMgt.AddElement(XMLCurrNodeWs, 'TypeRequest', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Type', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdNumber
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TypeRequest
        XMLCurrNodeWs := XMLNewChildWs;

        // >>

        XmlMgt.AddElement(XMLCurrNodeWs, 'FieldFilter', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'DocType', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DocType
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'DocIdentification', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DocType
        XMLCurrNodeWs := XMLNewChildWs;

        // -- Sender

        XmlMgt.AddElement(XMLCurrNodeWs, 'Sender', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdentification', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdCountry', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdCountry
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdType', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdType
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdNumber', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdNumber
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdentification
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'DeptCode', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DeptCode
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Sender
        XMLCurrNodeWs := XMLNewChildWs;

        // -- Sender

        // ++ Receiver

        XmlMgt.AddElement(XMLCurrNodeWs, 'Receiver', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdentification', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdCountry', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdCountry
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdType', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdType
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdNumber', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdNumber
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdentification
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'DeptCode', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DeptCode
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Receiver
        XMLCurrNodeWs := XMLNewChildWs;

        // ++ Receiver

        XmlMgt.AddElement(XMLCurrNodeWs, 'DocDateBeginning', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DocDateBeginning
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'DocDateEnd', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DocDateEnd
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'SystemDateBeginning', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //SystemDateBeginning
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'SystemDateEnd', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //SystemDateEnd
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'FileCompressionType', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //FileCompressionType
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //FieldFilter
        XMLCurrNodeWs := XMLNewChildWs;

        // <<

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //publishDocument
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLCurrNodeWs := XMLNewChildWs;

        //test
        // DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestGetDownloads()
    var
        XmlDocWs: XmlDocument;
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        LbNameSpaceSoap: Label 'http://www.w3.org/2003/05/soap-envelope', Locked = true;
        LbNameSpaceHan: Label 'http://ws.seres.com/wsdl/20150301/HangingDownloads/', Locked = true;
        LbNameSpaceWsse: label 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd', Locked = true;

    begin
        XmlStr := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:han="http://ws.seres.com/wsdl/20150301/HangingDownloads/">' +
                  '</soap:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Header', '', 'soap', LbNameSpaceSoap, XMLNewChildWs);
        /*
                XMLCurrNodeWs := XMLNewChildWs;
                XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Security', '', 'wsse', LbNameSpaceWsse, XMLNewChildWs);
                //XmlMgt.AddAttribute(XMLCurrNodeWs, 'soap:mustUnderstand', 'true');
                XMLCurrNodeWs := XMLNewChildWs;
                XmlMgt.AddElement(XMLCurrNodeWs, 'UsernameToken', '', LbNameSpaceWsse, XMLNewChildWs);
                XMLCurrNodeWs := XMLNewChildWs;

                XmlMgt.AddElement(XMLCurrNodeWs, 'Username', UserName, LbNameSpaceWsse, XMLNewChildWs);
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

                XmlMgt.AddElement(XMLCurrNodeWs, 'Password', Password, LbNameSpaceWsse, XMLNewChildWs);
                XmlMgt.AddAttribute(XMLCurrNodeWs, 'Type', 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText');
                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XMLNewChildWs := XMLCurrNodeWs;

                XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
                XMLNewChildWs := XMLCurrNodeWs;
        */

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Header

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Body', '', 'soap', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'getDownloads', '', 'han', LbNameSpaceHan, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'parameters', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'EFacturaService', 'PERU', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //EFacturaService
        XMLCurrNodeWs := XMLNewChildWs;

        // >>

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdentification', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdCountry', 'PE', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdCountry
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdType', '6', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdType
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdNumber', '20563249090', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdNumber
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdentification
        XMLCurrNodeWs := XMLNewChildWs;

        // <<

        XmlMgt.AddElement(XMLCurrNodeWs, 'DocId', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DocId
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Operation', '?', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Operation
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //publishDocument
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLCurrNodeWs := XMLNewChildWs;

        //test
        // DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestConfirmDownloads(var XmlDocWs: XmlDocument; CompanyInfo: Record "Company Information"; RecGLSetup: Record "General Ledger Setup"; DocType: Code[20]; UserName: Text[50]; Password: Text[50]; DocTypeFile: Code[20]; DocID: Code[20])
    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        LbNameSpaceSoap: Label 'http://www.w3.org/2003/05/soap-envelope', Locked = true;
        LbNameSpaceHan: Label 'http://ws.seres.com/wsdl/20150301/HangingDownloads/', Locked = true;
        LbNameSpaceWsse: label 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd', Locked = true;

    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:han="http://ws.seres.com/wsdl/20150301/HangingDownloads/">' +
                  '</soap:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        //XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Header', '', 'soap', LbNameSpaceSoap, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Security', '', 'wsse', LbNameSpaceWsse, XMLNewChildWs);
        //XmlMgt.AddAttribute(XMLCurrNodeWs, 'soap:mustUnderstand', 'true');
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.AddElement(XMLCurrNodeWs, 'UsernameToken', '', LbNameSpaceWsse, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Username', UserName, LbNameSpaceWsse, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Password', Password, LbNameSpaceWsse, XMLNewChildWs);
        //XmlMgt.AddAttribute(XMLCurrNodeWs, 'Type', 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText');
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Header
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        //XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'Body', '', 'soap', LbNameSpaceSoap, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElementWithPrefix(XMLCurrNodeWs, 'confirmDownloads', '', 'han', LbNameSpaceHan, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'parameters', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'EFacturaService', RecGLSetup."Servicio Facturacion E", '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //EFacturaService
        XMLNewChildWs := XMLCurrNodeWs;

        // >>

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdentification', '', '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdCountry', RecGLSetup."Codigo Pais", '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdCountry
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdType', CompanyInfo."LOCPE_Doc. Type SUNAT", '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdType
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'TaxIdNumber', CompanyInfo."VAT Registration No.", '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdNumber
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //TaxIdentification
        XMLNewChildWs := XMLCurrNodeWs;

        // <<

        XmlMgt.AddElement(XMLCurrNodeWs, 'DocId', DocID, '', XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //DocId
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //publishDocument
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        // DownloadXml(XmlDocWs);

    end;

    /// <summary>
    /// Arma Xml para Consulta de Estado de Comprobante
    /// </summary>
    /// <param name="XmlDocWs">Xml formateado</param>
    /// <param name="CompanyInfo"></param>
    /// <param name="UserName"></param>
    /// <param name="Password"></param>
    procedure CreateWsRequestGetDocumentsState(
    var XmlDocWs: XmlDocument;
    RecCompanyInformation: Record "Company Information";
    UserName: Text[50];
    Password: Text[50];
    RecSalesInvoiceHeader: Record "Sales Invoice Header"
    )

    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        XmlStrCData: Text;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceSFE: Label 'http://com.conastec.sfe/ws/schema/sfe', Locked = true;
        CRLF: Text[2];

    begin
        //Valores para salto de línea
        CRLF[1] := 13;
        CRLF[2] := 10;

        XmlStr := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sfe="http://com.conastec.sfe/ws/schema/sfe">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'consultarEstadoComprobanteRequest', '', LbNameSpaceSFE, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlStrCData := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + CRLF;
        XmlStrCData := XmlStrCData +
        '<consultarEstadoComprobante> ' + CRLF +
        '   <header>' + CRLF +
        '       <fechaTransaccion>2022-01-04 12:25:16</fechaTransaccion>' + CRLF +
        '       <idEmisor>20489332621</idEmisor>' + CRLF +
        '       <token>amHjidfk2O0A5/BK5uTfwjk9V9I=</token>' + CRLF +
        '       <transaccion>consultarEstadoComprobanteRequest</transaccion>' + CRLF +
        '   </header>' + CRLF +
        '   <idEmisor>20489332621</idEmisor>' + CRLF +
        '   <listaComprobantes>' + CRLF +



        '     <comprobante>' + CRLF +
        '       <tipoDocumento>' + RecSalesInvoiceHeader."LOCPE_Doc. Type SUNAT" + '</tipoDocumento>' + CRLF +
        '       <serie>' + COPYSTR(RecSalesInvoiceHeader."No.", 1, 4) + '</serie>' + CRLF +
        '       <correlativo>' + COPYSTR(RecSalesInvoiceHeader."No.", 6, 8) + '</correlativo>' + CRLF +
        '       <rucEmisor>' + RecCompanyInformation."VAT Registration No." + '</rucEmisor>' + CRLF +
        '     </comprobante>' + CRLF +
        // '     <comprobante>' + CRLF +
        // '       <tipoDocumento>01</tipoDocumento>' + CRLF +
        // '       <serie>FF01</serie>' + CRLF +
        // '       <correlativo>00000267</correlativo>' + CRLF +
        // '       <rucEmisor>20538537145</rucEmisor>' + CRLF +
        // '     </comprobante>' + CRLF +
        '   </listaComprobantes>' + CRLF +
        '</consultarEstadoComprobante>' + CRLF;

        //Establece CData
        XmlMgt.AddElementCData(XMLCurrNodeWs, 'data', XmlStrCData, LbNameSpaceSFE, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //data
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //consultarEstadoComprobante
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        DownloadXml(XmlDocWs);

    end;

    local procedure InitXmlDocumentWithText(StrXml: Text; var XmlDoc: XmlDocument; var XmlCurrNode: XmlNode)
    var
        XmlList: XmlNodeList;
        LbErrorXmlText: Label 'The XML document for the web service was not initialized.';
    begin
        if StrXml = '' then
            Error(LbErrorXmlText);

        XmlMgt.LoadXMLDocumentFromText(StrXml, XmlDoc);

        XmlList := XmlDoc.GetChildNodes();
        XmlList.Get(XmlList.Count, XmlCurrNode);

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
        FileName := 'solicitud.xml';
        DownloadFromStream(InStr, 'XML FILE', '', '', FileName);

    end;


    local procedure DIN_FUN_CONVERTIR_NUMEROS_LETRA(Numero: Decimal; Moneda: Text): Text;
    var

        Monto: Text[200];
        lnEntero: INTEGER;
        lcRetorno: Text[512];
        lnTerna: INTEGER;
        lcMiles: Text[512];
        lcCadena: Text[512];
        lnUnidades: INTEGER;
        lnDecenas: INTEGER;
        lnCentenas: INTEGER;
        lnFraccion: INTEGER;
        Letras: Report "Check Translation Management";
        NoTextz: array[2] of Text[80];
        _moneda: Text;
        _monedaDoc: Text;
    begin

        if (Moneda = '') then begin
            _moneda := '';
            _monedaDoc := 'SOLES';
        end
        else begin
            _moneda := Moneda;
            _monedaDoc := 'DOLARES';
        end;


        Letras.FormatNoText(NoTextz, Numero, 2058, _moneda, _monedaDoc);

        Monto := NoTextz[1];
        EXIT(Monto);


    end;

    local procedure ReplaceString(String: Text[250]; FindWhat: Text[250]; ReplaceWith: Text[250]) NewString: Text[250]
    var
    begin
        WHILE STRPOS(String, FindWhat) > 0 DO
            String := DELSTR(String, STRPOS(String, FindWhat)) + ReplaceWith + COPYSTR(String, STRPOS(String, FindWhat) + STRLEN(FindWhat));
        NewString := String;
    end;

    procedure CreateWsRequestConfirmDocuments(var XmlDocWs: XmlDocument;
    CompanyInfo: Record "Company Information";
    DocType: Code[20];
    UserName: Text[50];
    Password: Text[50];
    DocID: Code[20];
    Serie: Text[10];
    Numero: Integer)

    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        Numerox: Integer;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceTem: Label 'http://tempuri.org/', Locked = true;
        LbNameSpaceLib: Label 'http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion', Locked = true;
        LbNameSpaceArr: Label 'http://schemas.microsoft.com/2003/10/Serialization/Arrays', Locked = true;
        LbNameSpaceDll1: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConfirmarRespuestaComprobante', Locked = true;
        LbNameSpaceDll: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio', Locked = true;

        LbNameSpaceLoad: Label 'http://ws.seres.com/wsdl/20150301/LoadsDocuments/', Locked = true;
        LbNameSpaceWsse: label 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd', Locked = true;

    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:dll="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio" xmlns:lib="http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion" xmlns:dll1="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConfirmarRespuestaComprobante">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ConfirmarRespuestaComprobante', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENconsulta', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Autenticacion', '', LbNameSpaceDll, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Clave', Password, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', UserName, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        // evaluate(Numerox, CopyStr(DocID, 6, 8));

        XmlMgt.AddElement(XMLCurrNodeWs, 'DetalleComprobante', '', LbNameSpaceDll1, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ENDetalleComprobante', '', LbNameSpaceDll1, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Numero', FORMAT(Numero, 0), LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Serie', Serie, LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoComprobante', DocType, LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'RucEmisor', CompanyInfo."VAT Registration No.", LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Obtener_PDF
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestGetDocumentsStateRetention(
    var XmlDocWs: XmlDocument;
    CompanyInfo: Record "Company Information";
    UserName: Text[50];
    Password: Text[50])
    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceRet: Label 'http://tci.net.pe/WS_eCica/Retencion/', Locked = true;


    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ret="http://tci.net.pe/WS_eCica/Retencion/">' +
                '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ConsultarRespuestaRetencion', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ent_ConsultarRespuesta', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ent_Autenticacion', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Ruc', UserName, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Clave', Password, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_NumeroDocumentoIdentidad', CompanyInfo."VAT Registration No.", LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'at_CantidadConsultar', '1', LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Obtener_PDF
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        // DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestConfirmDocumentsRetention(var XmlDocWs: XmlDocument;
        CompanyInfo: Record "Company Information";
        CodigoRespuesta: Code[20];
        UserName: Text[50];
        Password: Text[50];
        DocID: Code[20];
        Serie: Text[10];
        Numero: Text[10])

    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        Numerox: Integer;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceRet: Label 'http://tci.net.pe/WS_eCica/Retencion/', Locked = true;

    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ret="http://tci.net.pe/WS_eCica/Retencion/">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ConfirmarRespuestaRetencion', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ent_ConfirmarRespuesta', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ent_Autenticacion', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Ruc', UserName, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Clave', Password, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_NumeroDocumentoIdentidad', CompanyInfo."VAT Registration No.", LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'l_ComprobanteConfirmarRespuesta', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'en_ComprobanteConfirmarRespuesta', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Serie', Serie, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Numero', Numero, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'at_CodigoRespuesta', CodigoRespuesta, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //l_ComprobanteConfirmarRespuesta
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //en_ComprobanteConfirmarRespuesta
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //en_ComprobanteConfirmarRespuesta
        XMLNewChildWs := XMLCurrNodeWs;


        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Obtener_PDF
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestDownloadsDocumentsReten(var XmlDocWs: XmlDocument;
    CompanyInfo: Record "Company Information";
    DocType: Code[20];
    UserName: Text[50];
    Password: Text[50];
    DocID: Code[20])

    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        Numerox: Integer;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceRet: Label 'http://tci.net.pe/WS_eCica/Retencion/', Locked = true;

    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ret="http://tci.net.pe/WS_eCica/Retencion/">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ConsultarRepresentacionImpresaRetencion', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ent_ConsultarRI', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ent_Autenticacion', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Ruc', UserName, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Clave', Password, LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_NumeroDocumentoIdentidad', CompanyInfo."VAT Registration No.", LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


        XmlMgt.AddElement(XMLCurrNodeWs, 'ent_Comprobante', '', LbNameSpaceRet, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        evaluate(Numerox, CopyStr(DocID, 6, 8));

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Serie', CopyStr(DocID, 1, 4), LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'at_Numero', FORMAT(Numerox, 0), LbNameSpaceRet, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ent_Comprobante
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;


        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Obtener_PDF
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        DownloadXml(XmlDocWs);

    end;


    procedure CreateWsRequestLoadsDocumentsBaja(
        var XmlDocWs: XmlDocument;
        CompanyInfo: Record "Company Information";
        RecGLSetup: Record "General Ledger Setup";
        DocType: Code[20];
        RecSalesInvoiceHeaderNC: Record "Sales Cr.Memo Header";
        UserName: Text[50]; Password: Text[50])
    var
        RecCompanyInformation: Record "Company Information";
        RecsalesInvoice: Record "Sales Invoice Header";

        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceTem: Label 'http://tempuri.org/', Locked = true;
        LbNameSpaceLib: Label 'http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion', Locked = true;
        LbNameSpaceArr: Label 'http://schemas.microsoft.com/2003/10/Serialization/Arrays', Locked = true;
        LbNameSpaceDll: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio', Locked = true;
        Numerox: Integer;
    begin
        RecsalesInvoice.Reset();
        RecsalesInvoice.SetRange("No.", RecSalesInvoiceHeaderNC."Applies-to Doc. No.");
        RecsalesInvoice.FindSet();

        RecCompanyInformation.GET();

        //Fin cargar datos         
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:lib="http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays" xmlns:dll="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'RegistrarComunicacionBaja', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oGeneral', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Autenticacion', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Clave', Password, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', UserName, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENEmpresa', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', RecCompanyInformation."VAT Registration No.", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENEmpresa
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENEmpresa
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENNumeradosNoEmitidosCab', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'FechaEmision', FORMAT(RecsalesInvoice."Document Date", 0, '<Year4>-<Month,2>-<Day,2>'), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'FechaGeneracion', FORMAT(Today, 0, '<Year4>-<Month,2>-<Day,2>'), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);


        XmlMgt.AddElement(XMLCurrNodeWs, 'NumeradosNoEmitidos', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ENNumeradosNoEmitidos', '', LbNameSpaceLib, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'CodigoTipoDocumento', RecsalesInvoice."LOCPE_Doc. Type SUNAT", LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'Item', '1', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'MotivoBaja', 'Anulacion de Operación', LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        evaluate(Numerox, CopyStr(RecsalesInvoice."No.", 6, 8));

        XmlMgt.AddElement(XMLCurrNodeWs, 'NumeroDocumento', FORMAT(Numerox, 0), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'SerieDocumento', CopyStr(RecsalesInvoice."No.", 1, 4), LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);





        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //ENNumeradosNoEmitidos
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //NumeradosNoEmitidos
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENNumeradosNoEmitidosCab
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oGeneral
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //RegistrarComunicacionBaja
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestGetDocumentsStateBaja(
   var XmlDocWs: XmlDocument;
   CompanyInfo: Record "Company Information";
   UserName: Text[50];
   Password: Text[50])
    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceTem: Label 'http://tempuri.org/', Locked = true;
        LbNameSpaceDll: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio', Locked = true;
        LbNameSpaceLib: Label 'http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion', Locked = true;
        LbNameSpaceDll1: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConsultarRespuestaResumen', Locked = true;


    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:dll="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio" xmlns:lib="http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion" xmlns:dll1="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConsultarRespuestaResumen">' +
                '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ConsultarRespuestaResumen', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENconsulta', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Autenticacion', '', LbNameSpaceDll, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Clave', Password, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', UserName, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'CantidadResumen', '1', LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XmlMgt.AddElement(XMLCurrNodeWs, 'RucEmisor', CompanyInfo."VAT Registration No.", LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //oENPeticion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Obtener_PDF
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        DownloadXml(XmlDocWs);

    end;

    procedure CreateWsRequestConfirmDocumentsBaja(var XmlDocWs: XmlDocument;
        CompanyInfo: Record "Company Information";
        CodigoRespuesta: Code[20];
        UserName: Text[50];
        Password: Text[50];
        DocID: Code[20];
        NombreResumen: Text[50];
        TipoResumen: Text[10])
    var
        XMLCurrNodeWs: XmlNode;
        XMLNewChildWs: XmlNode;
        XmlStr: Text;
        Numerox: Integer;
        LbNameSpaceSoap: Label 'http://schemas.xmlsoap.org/soap/envelope/', Locked = true;
        LbNameSpaceTem: Label 'http://tempuri.org/', Locked = true;
        LbNameSpaceDll: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio', Locked = true;
        LbNameSpaceLib: Label 'http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion', Locked = true;
        LbNameSpaceDll1: Label 'http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConfirmarRespuestaResumen', Locked = true;

    begin
        XmlStr := '<?xml version="1.0" encoding="UTF-8"?>' + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/" xmlns:dll="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio" xmlns:lib="http://schemas.datacontract.org/2004/07/Libreria.XML.Facturacion" xmlns:dll1="http://schemas.datacontract.org/2004/07/DLL_EntidadNegocio.ConfirmarRespuestaResumen">' +
                 '</soapenv:Envelope>';

        InitXmlDocumentWithText(XmlStr, XmlDocWs, XMLCurrNodeWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Header', '', LbNameSpaceSoap, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Body', '', LbNameSpaceSoap, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ConfirmarRespuestaResumen', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'oENconsulta', '', LbNameSpaceTem, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Autenticacion', '', LbNameSpaceDll, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'Clave', Password, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'Ruc', UserName, LbNameSpaceLib, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'DetalleResumen', '', LbNameSpaceDll1, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'ENDetalleResumen', '', LbNameSpaceDll1, XMLNewChildWs);
        XMLCurrNodeWs := XMLNewChildWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'IdResumenCliente', CodigoRespuesta, LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'NombreResumen', NombreResumen, LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.AddElement(XMLCurrNodeWs, 'TipoResumen', TipoResumen, LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //Autenticacion
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.AddElement(XMLCurrNodeWs, 'RucEmisor', CompanyInfo."VAT Registration No.", LbNameSpaceDll1, XMLNewChildWs);
        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs);  //l_ComprobanteConfirmarRespuesta
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //parameters
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Obtener_PDF
        XMLNewChildWs := XMLCurrNodeWs;

        XmlMgt.GetParentNode(XMLCurrNodeWs, XMLNewChildWs); //Body
        XMLNewChildWs := XMLCurrNodeWs;

        //test
        //DownloadXml(XmlDocWs);

    end;

}
