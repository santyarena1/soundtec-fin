// Reusable search bar with input and submit button. Displays total count.
export default function SearchBar({ value, onChange, onSubmit, total }) {
  return (
    <>
      <div className="searchbar">
        <input
          placeholder="Código, nombre, marca…"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && onSubmit()}
          aria-label="Búsqueda"
        />
        <button className="btn" onClick={onSubmit}>
          Buscar
        </button>
      </div>
      <div className="summaryline">
        Total: <strong>{total}</strong>
      </div>
    </>
  );
}