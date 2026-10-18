// 서버 상품표 = 게임 data/iap.json 의 IAP_PRODUCTS (같은 파일을 묶어 넣음 — 표가 어긋나지 않게)
import iap from "../../godot/data/iap.json";

export interface Product {
  id: string;
  gold: number;
  google: string;
  apple: string;
  stove_item: string;
}

export const PRODUCTS: Product[] = (iap as { IAP_PRODUCTS: Product[] }).IAP_PRODUCTS.map((p) => ({
  id: String(p.id),
  gold: Number(p.gold),
  google: String(p.google),
  apple: String(p.apple),
  stove_item: String(p.stove_item),
}));

export function productById(id: string): Product | undefined {
  return PRODUCTS.find((p) => p.id === id);
}

/** 가게 상품 id (dev 가게는 게임 안 id 그대로) */
export function storeProductId(p: Product, store: string): string {
  switch (store) {
    case "google":
      return p.google;
    case "apple":
      return p.apple;
    case "stove":
      return p.stove_item;
    default:
      return p.id;
  }
}

export function productByStoreId(store: string, spid: string): Product | undefined {
  return PRODUCTS.find((p) => storeProductId(p, store) === spid);
}
