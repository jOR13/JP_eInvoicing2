enum 50561 "Tipo Documento"
{
    Extensible = true;

    value(0; Factura)
    {
        Caption = 'Factura';
    }
    value(1; "Nota de credito")
    {
        Caption = 'Nota de credito';
    }
    value(2; "Retencion")
    {
        Caption = 'Retencion';
    }
    value(3; "Baja")
    {
        Caption = 'Documento de baja';
    }

    // TODO Agregar tipos de documento según documentación
    // Factura
    // Boleta +
    // Nota de Crédito
    // Nota de Débito +
    // Retención
    // Percepción +

}