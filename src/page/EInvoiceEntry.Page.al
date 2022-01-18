page 50563 "E-Invoice Entry"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "E-Invoice Entry";
    InsertAllowed = false;
    Caption = 'Monitor de Envío E-Invoice';

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Elec. Document Status"; Rec."Elec. Document Status")
                {
                    ApplicationArea = All;
                }
                field("Document Type"; Rec."Document Type")
                {
                    ApplicationArea = All;

                }
                field("SUNAT DocType"; Rec."SUNAT DocType")
                {
                    ApplicationArea = All;
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                }
                field("Customer No."; Rec."Customer No.")
                {
                    ApplicationArea = All;
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ApplicationArea = All;
                }
                field("Customer Name 2"; Rec."Custemer Name 2")
                {
                    ApplicationArea = All;
                }

                field("Last Date"; Rec."Last Date")
                {
                    ApplicationArea = All;
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                }
                field("Response Code"; Rec."Response Code")
                {
                    ApplicationArea = All;
                }
                field("Response Web Service"; Rec."Response Web Service")
                {
                    ApplicationArea = All;
                }
                field("Response Observations"; Rec."Response Observations")
                {
                    ApplicationArea = All;
                }
                field("Error Code"; Rec."Error Code")
                {
                    ApplicationArea = All;
                }
                Field("Error Description"; Rec."Error Description")
                {
                    ApplicationArea = All;
                }

            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(Factura)
            {
                action("Check Status")
                {
                    ApplicationArea = All;
                    Caption = 'Verificacion de estado';
                    Image = Status;

                    trigger OnAction()
                    var
                        SERESGetDocumentStatus: Codeunit "WS Prov Get Document Status";

                    begin
                        SERESGetDocumentStatus.Code('01');
                    end;
                }
                //             Action("Dowload File")
                //             {
                //                 ApplicationArea = All;
                //                 Caption = 'Descarga de Archivo';
                //                 Image = ExportFile;

                //                 trigger OnAction()
                //                 var
                //                     SERESDownload: Codeunit SERESDownloadEInvoice;
                //                 Begin
                //                     SERESDownload.Code('01');
                //                 End;
                //             }
                //             // action("Download Confirm")
                //             // {
                //             //     ApplicationArea = All;
                //             //     Caption = 'Confirmacion de estado';
                //             //     Image = Confirm;
                //             //     Trigger OnAction()
                //             //     var
                //             //     //SERESDownloadConfirm: Codeunit "SERES Download Confirm";
                //             //     Begin
                //             //         //SERESDownloadConfirm.Code('01');
                //             //     End;
                //             // }
            }

            //         group("Nota de Credito")
            //         {
            //             action("Check Cr.Memo Status")
            //             {
            //                 ApplicationArea = All;
            //                 Caption = 'Verificacion de estado';
            //                 Image = Status;

            //                 trigger OnAction()
            //                 var
            //                     SERESGetDocumentStatus: Codeunit "SERES Get Document Status";
            //                 begin
            //                     SERESGetDocumentStatus.Code('02');
            //                 end;
            //             }
            //             Action("Dowload Cr. Memo File")
            //             {
            //                 ApplicationArea = All;
            //                 Caption = 'Descargar Archivo';
            //                 image = Export;

            //                 trigger OnAction()
            //                 var
            //                     SERESDownload: Codeunit SERESDownloadEInvoice;
            //                 Begin
            //                     SERESDownload.Code('02');
            //                 End;
            //             }
            //             // action("Download Cr. Memo Confirm")
            //             // {
            //             //     ApplicationArea = All;
            //             //     Caption = 'Confirmacion de estado';
            //             //     Image = Confirm;

            //             //     Trigger OnAction()
            //             //     var
            //             //     // SERESDownloadConfirm: Codeunit "SERES Download Confirm";
            //             //     Begin
            //             //         // SERESDownloadConfirm.Code('02');
            //             //     End;
            //             // }
            //         }

            //         group("Retenciones")
            //         {
            //             action("Check Retention Status")
            //             {
            //                 ApplicationArea = All;
            //                 Caption = 'Verificacion de estado';
            //                 Image = Status;

            //                 trigger OnAction()
            //                 var
            //                     SERESGetDocumentStatus: Codeunit "SERES Get Document Status";
            //                 begin
            //                     SERESGetDocumentStatus.CodeRetention();
            //                 end;
            //             }
            //             Action("Dowload Retention File")
            //             {
            //                 ApplicationArea = All;
            //                 Caption = 'Descargar Archivo';
            //                 image = Export;

            //                 trigger OnAction()
            //                 var
            //                     SERESDownload: Codeunit SERESDownloadEInvoice;
            //                 Begin
            //                     SERESDownload.CodeReten();
            //                 End;
            //             }
            //         }

            //         group("Bajas Factura")
            //         {
            //             action("Bajas Invoice")
            //             {
            //                 ApplicationArea = All;
            //                 Caption = 'Verificacion y confirmacion baja';
            //                 Image = Status;

            //                 trigger OnAction()
            //                 var
            //                     SERESGetDocumentStatus: Codeunit "SERES Get Document Status";
            //                 begin
            //                     SERESGetDocumentStatus.CodeBaja();
            //                 end;
            //             }

            //         }
            //         group(Exportar)
            //         {
            //             // action("Export XML")
            //             // {
            //             //     ApplicationArea = All;
            //             //     Caption = 'Descargar XML';
            //             //     Image = XMLFile;

            //             //     Trigger OnAction()
            //             //     var
            //             //         TempBlob: Codeunit "Temp Blob";
            //             //         ttt: Record "Sales Invoice Header";
            //             //         InStr: InStream;
            //             //         TextName: Text;

            //             //     Begin
            //             //         CalcFields("Document XML");
            //             //         if "Document XML".Length <> 0 then begin
            //             //             "Document XML".CreateInStream(InStr);
            //             //             TextName := Format("Document No.") + '.xml';
            //             //             DownloadFromStream(InStr, 'Descargar XML', '', '', TextName);
            //             //         end else
            //             //             Error('Not found file');

            //             //     End;
            //             // }
            //             action("Export PDF")
            //             {
            //                 ApplicationArea = All;
            //                 Caption = 'Descargar PDF';
            //                 Image = SendAsPDF;
            //                 Trigger OnAction()
            //                 var
            //                     TempBlob: Codeunit "Temp Blob";
            //                     ttt: Record "Sales Invoice Header";
            //                     InStr: InStream;
            //                     TextName: Text;

            //                 Begin
            //                     CalcFields("Document PDF");
            //                     if "Document PDF".Length <> 0 then begin
            //                         "Document PDF".CreateInStream(InStr);
            //                         TextName := Format("Document No.") + '.pdf';
            //                         DownloadFromStream(InStr, 'Descargar XML', '', '', TextName);
            //                     end else
            //                         Error('Not found file');
            //                 End;
            //             }
            //             // action("Export Send File")
            //             // {
            //             //     ApplicationArea = All;
            //             //     Caption = 'Descargar archivo de envio';
            //             //     image = ExportFile;

            //             //     trigger OnAction()
            //             //     var
            //             //         TempBlob: Codeunit "Temp Blob";
            //             //         InStr: InStream;
            //             //         TextName: Text;
            //             //         Chain: Text;
            //             //         tempblobzip: Codeunit "Temp Blob";
            //             //         Outstr: OutStream;
            //             //         InStrZip: InStream;
            //             //     // Base64Convert: Codeunit Base64Convert;
            //             //     begin
            //             //         CalcFields("File Base64");
            //             //         IF "File Base64".Length <> 0 THEN BEGIN
            //             //             "File Base64".CreateInStream(InStr);

            //             //             InStr.ReadText(Chain);
            //             //             TempBlobZip.CreateOutStream(OutStr);
            //             //             //Base64Convert.FromBase64StringToStream(Chain, Outstr);
            //             //             TempBlobZip.CreateInStream(InStrZip);
            //             //             TextName := Format("Document No.") + '.zip';
            //             //             DownloadFromStream(InStrZip, 'Descargar Archivo de envio', '', '', TextName);
            //             //         END;
            //             //     end;
            //             // }

            //         }

        }
    }

    trigger OnOpenPage()
    begin
        //Company Validate
        //ValidateActiveEInvoice();
        //Company Validate

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

}