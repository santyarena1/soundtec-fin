/**
 * pricing.ts (placeholder)
 * FÃ³rmula:
 *   finalAdmin = base * (1+markup) * (1+impuestos) * (1+iva)
 *   finalParaUsuario = finalAdmin * (1 - descuentoUsuario)
 */
export function calcularPrecio(baseUsd: number, markupPct: number, impuestosPct: number, ivaPct: number, descuentoUsuarioPct: number) {
  const finalAdmin = baseUsd * (1 + markupPct/100) * (1 + impuestosPct/100) * (1 + ivaPct/100);
  const finalUsuario = finalAdmin * (1 - descuentoUsuarioPct/100);
  return { finalAdmin, finalUsuario };
}
