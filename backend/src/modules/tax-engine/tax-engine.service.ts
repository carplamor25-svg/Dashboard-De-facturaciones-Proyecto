export interface InvoiceTaxData {
  taxBase: number;
  vatRate: number;
  vatAmount: number;
  irpfRate: number;
  irpfAmount: number;
  totalAmount: number;
}

export interface TaxModel303Summary {
  accruedVatBase21: number;
  accruedVatAmount21: number;
  accruedVatBase10: number;
  accruedVatAmount10: number;
  accruedVatBase4: number;
  accruedVatAmount4: number;
  totalAccruedVat: number; // IVA Repercutido

  deductibleVatBase: number;
  deductibleVatAmount: number; // IVA Soportado Deducible

  netVatResult: number; // Repercutido - Soportado (>0 a pagar, <0 a compensar)
}

export interface TaxModel111Summary {
  withholdingBase: number;
  withholdingAmount: number;
}

export class TaxEngineService {
  /**
   * Redondeo monetario preciso a 2 decimales para evitar problemas de coma flotante
   */
  roundCurrency(amount: number): number {
    return Math.round((amount + Number.EPSILON) * 100) / 100;
  }

  /**
   * Algoritmo oficial de validación de NIF / NIE / CIF de la AEAT
   */
  validateSpanishTaxId(taxId: string): { valid: boolean; type?: 'NIF' | 'NIE' | 'CIF'; error?: string } {
    if (!taxId) return { valid: false, error: 'Identificador fiscal vacío' };

    const clean = taxId.toUpperCase().trim().replace(/[-\s]/g, '');
    if (clean.length !== 9) return { valid: false, error: 'Longitud incorrecta (debe tener 9 caracteres)' };

    // 1. DNI / NIF estándar (8 números + 1 letra)
    const dniRegex = /^(\d{8})([A-Z])$/;
    const dniMatch = clean.match(dniRegex);
    if (dniMatch) {
      const letters = 'TRWAGMYFPDXBNJZSQVHLCKE';
      const num = parseInt(dniMatch[1], 10);
      const expectedLetter = letters[num % 23];
      return dniMatch[2] === expectedLetter
        ? { valid: true, type: 'NIF' }
        : { valid: false, error: `Letra de NIF incorrecta (esperada: ${expectedLetter})` };
    }

    // 2. NIE (X, Y, Z + 7 números + 1 letra)
    const nieRegex = /^([XYZ])(\d{7})([A-Z])$/;
    const nieMatch = clean.match(nieRegex);
    if (nieMatch) {
      const prefixMap: Record<string, string> = { X: '0', Y: '1', Z: '2' };
      const fullNumStr = prefixMap[nieMatch[1]] + nieMatch[2];
      const num = parseInt(fullNumStr, 10);
      const letters = 'TRWAGMYFPDXBNJZSQVHLCKE';
      const expectedLetter = letters[num % 23];
      return nieMatch[3] === expectedLetter
        ? { valid: true, type: 'NIE' }
        : { valid: false, error: `Letra de NIE incorrecta (esperada: ${expectedLetter})` };
    }

    // 3. CIF (Letra + 7 números + dígito de control o letra)
    const cifRegex = /^([ABCDEFGHJNPQRSUVW])(\d{7})([0-9A-J])$/;
    const cifMatch = clean.match(cifRegex);
    if (cifMatch) {
      const letter = cifMatch[1];
      const digits = cifMatch[2];
      const control = cifMatch[3];

      let evenSum = 0;
      let oddSum = 0;

      for (let i = 0; i < digits.length; i++) {
        const n = parseInt(digits[i], 10);
        if (i % 2 === 0) {
          // Posición impar (1-indexed)
          const doubled = n * 2;
          oddSum += doubled > 9 ? doubled - 9 : doubled;
        } else {
          // Posición par
          evenSum += n;
        }
      }

      const totalSum = evenSum + oddSum;
      const controlDigit = (10 - (totalSum % 10)) % 10;
      const controlLetters = 'JABCDEFGHI';

      // Tipos donde el control debe ser letra o número
      const requiresLetter = ['P', 'Q', 'S', 'K', 'W'].includes(letter);
      const requiresNumber = ['A', 'B', 'E', 'H'].includes(letter);

      if (requiresLetter) {
        return control === controlLetters[controlDigit]
          ? { valid: true, type: 'CIF' }
          : { valid: false, error: 'Dígito de control de CIF incorrecto (letra)' };
      }

      if (requiresNumber) {
        return control === controlDigit.toString()
          ? { valid: true, type: 'CIF' }
          : { valid: false, error: 'Dígito de control de CIF incorrecto (número)' };
      }

      // El resto puede ser letra o número
      const isValid = control === controlDigit.toString() || control === controlLetters[controlDigit];
      return isValid
        ? { valid: true, type: 'CIF' }
        : { valid: false, error: 'Dígito de control de CIF incorrecto' };
    }

    return { valid: false, error: 'Formato de NIF/NIE/CIF desconocido' };
  }

  /**
   * Validar cuadre aritmético estricto de la factura: Total = Base + IVA - IRPF
   */
  validateArithmeticBalance(data: InvoiceTaxData): { balanced: boolean; calculatedTotal: number; difference: number } {
    const roundedBase = this.roundCurrency(data.taxBase);
    const roundedVat = this.roundCurrency(data.vatAmount);
    const roundedIrpf = this.roundCurrency(data.irpfAmount);
    const declaredTotal = this.roundCurrency(data.totalAmount);

    const calculatedTotal = this.roundCurrency(roundedBase + roundedVat - roundedIrpf);
    const difference = this.roundCurrency(Math.abs(declaredTotal - calculatedTotal));

    // Tolerancia de hasta 0.02 € por desfases de redondeo línea por línea
    const balanced = difference <= 0.02;

    return {
      balanced,
      calculatedTotal,
      difference
    };
  }

  /**
   * Cálculo de agregación trimestral para el Modelo 303 de la AEAT
   */
  calculateModel303(invoices: Array<{ invoiceType: 'INGRESO' | 'GASTO'; taxBase: number; vatRate: number; vatAmount: number }>): TaxModel303Summary {
    let accruedVatBase21 = 0;
    let accruedVatAmount21 = 0;
    let accruedVatBase10 = 0;
    let accruedVatAmount10 = 0;
    let accruedVatBase4 = 0;
    let accruedVatAmount4 = 0;
    let totalAccruedVat = 0;

    let deductibleVatBase = 0;
    let deductibleVatAmount = 0;

    for (const inv of invoices) {
      if (inv.invoiceType === 'INGRESO') {
        if (inv.vatRate === 21) {
          accruedVatBase21 += inv.taxBase;
          accruedVatAmount21 += inv.vatAmount;
        } else if (inv.vatRate === 10) {
          accruedVatBase10 += inv.taxBase;
          accruedVatAmount10 += inv.vatAmount;
        } else if (inv.vatRate === 4) {
          accruedVatBase4 += inv.taxBase;
          accruedVatAmount4 += inv.vatAmount;
        }
        totalAccruedVat += inv.vatAmount;
      } else if (inv.invoiceType === 'GASTO') {
        deductibleVatBase += inv.taxBase;
        deductibleVatAmount += inv.vatAmount;
      }
    }

    totalAccruedVat = this.roundCurrency(totalAccruedVat);
    deductibleVatAmount = this.roundCurrency(deductibleVatAmount);
    const netVatResult = this.roundCurrency(totalAccruedVat - deductibleVatAmount);

    return {
      accruedVatBase21: this.roundCurrency(accruedVatBase21),
      accruedVatAmount21: this.roundCurrency(accruedVatAmount21),
      accruedVatBase10: this.roundCurrency(accruedVatBase10),
      accruedVatAmount10: this.roundCurrency(accruedVatAmount10),
      accruedVatBase4: this.roundCurrency(accruedVatBase4),
      accruedVatAmount4: this.roundCurrency(accruedVatAmount4),
      totalAccruedVat,
      deductibleVatBase: this.roundCurrency(deductibleVatBase),
      deductibleVatAmount,
      netVatResult
    };
  }
}

export const taxEngineService = new TaxEngineService();

