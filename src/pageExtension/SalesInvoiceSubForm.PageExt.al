pageextension 50565 "Ext. Sales Invoice Sub" extends "Sales Invoice Subform"
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