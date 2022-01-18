pageextension 50564 "ExtPageCrMemoHeader" extends "Posted Sales Credit Memo"
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
                    Caption = 'Enviar Nota de credito - CONASTEC';
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
            }
            group(Baja)
            {
                Caption = 'Comunicacion de Baja';

                action(ExportarBaja)
                {
                    Caption = 'Enviar Comunicacion de Baja';
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        EinvoiceMGT: Codeunit "E-Invoice PE MGT";
                        RecRef: RecordRef;
                        EInvoiceEntry: Record "E-Invoice Entry";

                    Begin
                        //EInvoiceEntry.DeleteAll();
                        RecRef.GetTable(Rec);
                        EinvoiceMGT.CodeBaja(RecRef);
                    End;
                }
            }
        }
    }

    var
        myInt: Integer;
}