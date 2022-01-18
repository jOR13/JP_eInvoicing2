pageextension 50561 "SalesInvoiceCardExt" extends "Posted Sales Invoice"
{
    layout
    {
        addlast(General)
        {
            field(Processed; Rec.Processed)
            {
                ApplicationArea = All;
                Editable = False;
            }
            field(Status; Rec.Status)
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        addafter(Print)
        {
            group(Exportar)
            {
                Caption = 'Exportar';

                action(ExportarZiP)
                {
                    Caption = 'Enviar Factura a Facturador Elec.';
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        EinvoiceMGT: Codeunit "E-Invoice PE MGT";
                        RecRef: RecordRef;
                        EInvoiceEntry: Record "E-Invoice Entry";

                    Begin
                        //EInvoiceEntry.DeleteAll();
                        RecRef.GetTable(Rec);
                        EinvoiceMGT.Code(RecRef);
                    End;
                }

                action(DescargarPDF)
                {
                    ApplicationArea = All;
                    Caption = 'Exportar a PDF';
                    Image = SendAsPDF;
                    Trigger OnAction()
                    var
                        TempBlob: Codeunit "Temp Blob";
                        RecRef: RecordRef;
                        RecEInvoiceEntry: Record "E-Invoice Entry";

                        InStr: InStream;
                        TextName: Text;

                    Begin
                        RecEInvoiceEntry.SETRANGE("Document Type", 0);
                        RecEInvoiceEntry.SETRANGE("Document No.", Rec."No.");

                        if RecEInvoiceEntry.FINDFIRST then begin
                            if RecEInvoiceEntry."Document PDF".Length <> 0 then begin
                                RecEInvoiceEntry."Document PDF".CreateInStream(InStr);

                                TextName := Format(RecEInvoiceEntry."Document No.") + '.pdf';
                                DownloadFromStream(InStr, 'Descargar XML', '', '', TextName);
                            end
                            else begin
                                Error('No se encontró archivo');
                            end;
                        end else
                            Error('No se encontró archivo');

                    End;
                }
            }
        }
    }

    var
        myInt: Integer;
}