import Image from 'next/image';

type PadangLogoProps = {
  alt?: string;
  className?: string;
  priority?: boolean;
};

export function PadangLogo({ alt = 'Padang Construction and Supplies Corporation logo', className, priority = false }: PadangLogoProps) {
  const basePath = (process.env.NEXT_PUBLIC_BASE_PATH ?? '').replace(/\/+$/, '');

  return <Image className={className ?? 'brand-logo'} src={`${basePath}/assets/padang-logo.jpg`} alt={alt} width={834} height={721} priority={priority} />;
}
