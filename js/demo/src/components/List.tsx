import type { RibosomeListProps } from "../../../dist/index.js";

// HeroUI's ListBox expects keyed items, but Ribosome lists hold arbitrary
// rendered children, so this keeps semantic ol/ul styled with Tailwind tokens.
export const List = ({ id, ordered, children }: RibosomeListProps) => {
  const Tag = ordered ? "ol" : "ul";

  return (
    <Tag id={id} className={`flex flex-col gap-1 pl-6 ${ordered ? "list-decimal" : "list-disc"}`}>
      {children}
    </Tag>
  );
};
