page 50561 "Web Service Provider"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Web Service Provider";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Code; Rec.Codigo)
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Descripcion)
                {
                    ApplicationArea = All;
                }
                field(Type; Rec.Tipo)
                {
                    ApplicationArea = All;
                }
                field("User Name"; Rec.Usuario)
                {
                    ApplicationArea = All;
                }
                field(Password; Rec."Contraseña")
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
            action(Details)
            {
                ApplicationArea = All;
                Caption = 'Detalles';
                trigger OnAction()
                begin
                    CLEAR(PageDetails);
                    RecDetails.RESET;

                    RecDetails.SetRange(Codigo, Rec.Codigo);
                    PageDetails.SetTableView(RecDetails);
                    PageDetails.RunModal();
                end;
            }


        }
    }

    var
        PageDetails: Page "Web Service Provider Detail";
        RecDetails: Record "Web Service Provider Detail";
}