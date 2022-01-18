pageextension 50567 "Ext. Sales Order Sub" extends "Sales Order Subform"
{
    layout
    {
        addafter(Description)
        {
            field("Descripcion Larga"; Rec."Descripcion Larga")
            {
                ApplicationArea = All;
                ToolTip = 'Dinamika';
                MultiLine = true;
            }
        }
    }

    actions
    {
    }
}