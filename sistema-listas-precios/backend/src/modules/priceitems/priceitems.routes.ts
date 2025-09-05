import { Router } from 'express';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';
import {
  listPriceItemsController,
  getPriceItemController,
  updatePriceItemController,
  bulkUpdatePriceItemsController
} from './priceitems.controller';

const router = Router();

// Admin-only
router.use(authGuard, adminGuard);

router.get('/', listPriceItemsController);
router.get('/:id', getPriceItemController);
router.patch('/:id', updatePriceItemController);
router.post('/bulk-update', bulkUpdatePriceItemsController);

export default router;
