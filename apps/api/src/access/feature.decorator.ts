import { SetMetadata } from '@nestjs/common';
import type { FeatureKey } from './features.js';

export const FEATURE = 'feature';

export const Feature = (key: FeatureKey) => SetMetadata(FEATURE, key);
