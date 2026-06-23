-- ROIBAL-APP: Translate default (global) categories to Spanish

update public.categories set name = 'Comida y Almacén' where name = 'Food & Groceries' and user_id is null;
update public.categories set name = 'Transporte' where name = 'Transport' and user_id is null;
update public.categories set name = 'Servicios' where name = 'Utilities & Services' and user_id is null;
update public.categories set name = 'Ocio y Entretenimiento' where name = 'Leisure & Entertainment' and user_id is null;
update public.categories set name = 'Inversiones' where name = 'Investments' and user_id is null;
update public.categories set name = 'Otros' where name = 'Other' and user_id is null;
